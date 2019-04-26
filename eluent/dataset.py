import json, datetime, time, os
from glob import glob
import pylab as pl
import numpy as np
from scipy import stats
import pandas as pd
import matplotlib.pyplot as plt

from eluent.visualization import COLOR_MAP
import cmocean

# where your study data is located
# see README for input data format
DATA_ROOT = "irb"

# defines which features are included in each 
STUDY_FEATURES = {
    "motion": ["acc-x", "acc-y", "acc-z"], 
    "phasic": ["phasic"],
    "hr": ["hr"], 
    "bio": ["bvp", "temp"],
    "kinnunen": ["getting-started", "dealing-with-difficulties", 
                 "encountering-difficulties", "failing", "submitting", "succeeding"],
    "jupyter": ["execute", "mouseevent", "notebooksaved", "select", "textchunk"], 
    "q": ["q1", "q2", "q3", "q4"], 
    "notes": ["notesmetadata"], 
    "emotion": ["phasic", "hr"], 
    "acc": ["a-x", "a-y", "a-z"],
    "gyro": ["g-x", "g-y", "g-z"],
    "mag": ["m-x", "m-y", "m-z"],
    "iron": ["m-x", "m-y", "m-z", "g-x", "g-y", "g-z", "a-x", "a-y", "a-z"]
}

###########
# CLASSES #
###########

class MTS:
    """Container class for multivariate time-series data. Contains methods for reading, pre-processing, and aligning MTS feature data. """

    def __init__(self, users, feat_class):
        # Each user in users must have a corresponding folder in DATA_ROOT
        self.users = users
        # feat_class must be defined in STUDY_FEATURES
        self.feat_class = feat_class
        self.features = compile_features([feat_class])

        self.construct()
        self.samples = None

    def construct(self):
        umts, tsum = extractMTS(self.users, self.features)
        umts, user_bounds = resampleFeatureMTS(umts, self.features)

        self.data = umts
        self.user_bounds = user_bounds
        self.max_len = max(user_bounds.values())

    def __getitem__(self, key):
        return self.data[key]
    def __setitem__(self, key, value):
        self.data[key] = value
    def __delitem__(self, key):
        del self.data[key]
    def __repr__(self):
        return self.to_df

    # Clips values of a certain feature to a percentile
    # all values above the x-th percentile are clipped in value
    def clip(self, feat, percentile):
        feat_list = self.get_feat(feat)
        feat_list.sort()
        f_idx = self.features.index(feat)

        clip_val = feat_list[int(len(feat_list) * percentile)]
        print("Clipping feature: {} @ {}th pctl={}".format(feat, int(percentile*100), clip_val))
        for u in self.users:
            x = self.data[u][f_idx] 
            x[x > clip_val] = clip_val
            self.data[u][f_idx]  = x

    # Global normalization function
    #   feat can be a list of features, a single feature (str), or 'all'
    #
    #   how = 'zscore' performs global z-score normalization on the selected feature(s)
    #   how = 'minmax' performs global min-max normalization on the selected feature(s)
    #   
    #   clip determines the maximum values allowed, all values > clip are set to the clip value
    def normalize(self, feat, how, clip=None):
        if feat == 'all':
            feats = self.features
        else:
            feats = [feat]

        for feat in feats:
            feat_list = self.get_feat(feat)
            f_idx = self.features.index(feat)

            if how == 'minmax':
                f_min = min(feat_list)

                if clip:
                    f_max = clip
                else:
                    f_max = max(feat_list)

                print("Feat: {}, min={}, max={}".format(feat, f_min, f_max))
                if f_min == f_max:
                    continue

                for u, mts in self.data.items():
                    x = mts[f_idx]
                    self.data[u][f_idx] = (x - f_min) / (f_max - f_min)

            if how == 'zscore':
                mean = np.mean(feat_list)
                std = np.std(feat_list)
                print("Feat: {}, mean={}, std={}".format(feat, mean, std))

                if std < 1e-6:
                    continue
                for u, mts in self.data.items():
                    x = mts[f_idx]
                    x = (x - mean) / std

                    if clip:
                        x[x > clip] = clip

                    self.data[u][f_idx] = x

    def to_df(self):
        out = {}

        for u in self.users:
            for i in range(len(self.features)):
                out[(u, self.features[i])] = pd.Series(self.data[u][i])

        return pd.DataFrame(out)

    def get_user(self, user):
        return self.data[user]

    def get_feat(self, feat):
        out = []
        f_idx = self.features.index(feat)

        for u, mts in self.data.items():
            out += list(mts[f_idx])
        return out

    def get_track(self, user, feat):
        f_idx = self.features.index(feat)
        return self.data[user][f_idx]

    def extract_samples(self, L, normalize=True):
        sss = np.array([])
        bounds = [0]
        for u in self.users: 
            mts = self.data[u].copy()
            ss = subsequences(mts, L, normalize)
            bounds.append(bounds[-1] + ss.shape[0])
            if sss.shape[0] == 0:
                sss = ss
            else:
                sss = np.concatenate((sss, ss))
        word_shape = sss.shape[-2:]
        sss = sss.reshape(sss.shape[0], -1)

        self.L = L
        self.samples = sss
        self.bounds = bounds
        self.word_shape = word_shape
        print("Extracted N={} samples from {} MTS".format(len(sss), self.feat_class.title()))

        return sss

    def time2L(self, seconds):
        u = self.users[0]
        samples = self.data[u].shape[1]
        contents, f = get_file(os.path.join("irb", str(u)), "sessionmetadata")
        total_time = contents["elapsed_time"]
        L = int(seconds/total_time * samples)

        # always make L even
        if L % 2 == 1:
            L += 1

        return L

#############
# I/O TOOLS #
#############

# Loads JSON files from dataset folder
def get_file(folder, prefix):
    user = os.path.basename(folder)
    files = glob(folder + "/"+prefix+"*.json")
    if len(files) == 0:
        print("File not found", prefix, 'in', folder)
        return None, None
    else: 
        with open(files[0], 'r') as f: 
            contents = json.load(f)
            return contents, files[0]

# JSON saver utility
def save_jsonfile(name, data):
    with open(name, 'w') as outfile:
        json.dump(data, outfile)
    print("File saved!", name)

# saves MTS samples in a separate JSON file
def save_dataset(metadata, description, file_name):

    metadata['description'] = description

    if file_name[-5:] != '.json':
        file_name += '.json'

    out_file = os.path.join(DATA_ROOT, 'datasets', file_name)

    save_jsonfile(out_file, metadata)

#############
# VTT TOOLS #
#############

def format_vtt(s):
    hours, remainder = divmod(s, 3600)
    minutes, seconds = divmod(remainder, 60)
    seconds, milliseconds = divmod(seconds, 1)
    milliseconds = int(1000*milliseconds)
    return '{:02}:{:02}:{:02}.{:03}'.format(int(hours), int(minutes), int(seconds), milliseconds)

def plrgb2rgba(color):
    r,g,b,a = color
    r = int(r * 255)
    g = int(g * 255)
    b = int(b * 255)
    return "rgba(%i, %i, %i, %f)" % (r,g,b,a)

def sparsify(row):
    row = row[np.nonzero(row)]
    sparse = []
    curr_cw = None
    w = 0
    for c in row:
        if curr_cw == None:
            curr_cw = c

        if curr_cw == c:
            w += 1
        else:
            sparse.append((curr_cw, w))
            curr_cw = c
            w = 1

    sparse.append((curr_cw, w))
    return sparse

def save_subtitles(save_path, cgram, prefix):

    def make_vtt(u, codes, prefix):

        directory = os.path.join(save_path, str(u))
        filename = prefix+"_"+str(u)+".vtt"

        if not os.path.exists(directory):
            os.makedirs(directory)

        vtt_filename = os.path.join(directory, filename)
        
        with open(vtt_filename, 'w') as f:
            f.write("WEBVTT FILE\n")
            
            windows_past = 0
            
            for i, codeword in enumerate(codes):
                code_id, width = codeword
                code_id = int(code_id)
                
                start = (window_size/2) * windows_past
                end = start + ((window_size/2) * width)
                windows_past = windows_past + width

                start = format_vtt(start)
                end = format_vtt(end)
            
                f.write("\n%s --> %s\n"%(start, end))
                
                color = plrgb2rgba(colors[code_id])
                cue = {
                    "code": str(code_id),
                    "width": width,
                    "color": color,
                    "display": "<div style='background: %s'>%s</div>"% (color, code_id)
                }
                
                f.write(json.dumps(cue))
                f.write("\n")
        
        print("File saved!", vtt_filename)

    K = cgram.codebook.K
    users = cgram.users
    window_size = cgram.mts.word_shape[1]

    cm_props = COLOR_MAP[cgram.mts.feat_class]
    cm = cm_props[0]
    cm = cmocean.tools.lighten(cm, cm_props[1])
    cm = cmocean.tools.crop_by_percent(cm, cm_props[2], which=cm_props[3], N=None)
    if len(cm_props) == 6:
        cm = cmocean.tools.crop_by_percent(cm, cm_props[4], which=cm_props[5], N=None)

    values = list(range(K + 1))
    if hasattr(cgram, 'reorder_colors'):
        values = cgram.reorder_colors(values)

    colors = [cm((values[i]) / K) for i in range(K+1)]

    for i in range(len(users)):
        u = users[i]

        row = cgram.chromatogram[i]
        sparse_row = sparsify(row)
        make_vtt(u, sparse_row, prefix)

#############
# MTS TOOLS #
#############

# Reads user data and aligns time range
def adjust_data(folder, data, t, Fs):
    metadata,f = get_file(folder, "sessionmetadata")
    if metadata == None:
        print('ERROR', folder, t)
        return
  
    # ADJUST Y AND T RANGE    
    start = metadata["session_start"] - t
    end = metadata["session_end"] - t    
    t0 = start * Fs 
    t0 = start * Fs  if start > 0 else 0
    tf = end * Fs - 1 if end < len(data) else len(data)
    t0 = int(t0)
    tf = int(tf)
    data = data[t0:tf]
    return data

def compile_features(features):
    feat = []
    for f in features:
        feat.extend(STUDY_FEATURES[f])
    return feat

# Returns all subsequences of size L from a (a MTS matrix)
#   - if normalize = True, each L-sequence is normalized individually
def subsequences(a, L, normalize=False):
    n, m = a.shape
    windows = int(m/L)
    window_range = np.linspace(0, windows-1, (windows-1) * 2 + 1)
    ss = []
    for x in window_range:
        seq = a[:, int(x*L):int((x+1)*L)]
        if normalize:
            for i in range(seq.shape[0]):
                std = np.std(seq[i])
                if std == 0:
                    seq[i] = seq[i] - np.mean(seq[i])
                else:
                    seq[i] = (seq[i] - np.mean(seq[i])) / np.std(seq[i])
        ss.append(seq)
    return np.array(ss)

# Extracts study data into a multivariate timeseries matrix
def extractMTS(users, features):
    tsum = 0
    umts = {}
    for user in users: 
        # print(user)
        mts = []
        folder = os.path.join(DATA_ROOT, str(user))
            
        for feature in features: 
            contents, f = get_file(folder, feature)
            if not f:
                continue
                
            #Frequency encoded feature
            if "sampling_rate" in contents:
                data = contents["data"]
                t = contents["timestamp"]
                F = contents["sampling_rate"]
                # print(feature, '\tt_start: ', t, '\tsr: ', F)
                data = adjust_data(folder, data, t, F)
                mts.append(data)
                tsum = tsum + len(data)

            #Time encoded feature
            else:
                data = contents["data"]
                if "y" in data:
                    data = data["y"]
                mts.append(data)
                tsum = tsum + len(data)
        if len(mts) > 0:
            umts[user] = mts
        else:
            print("Insufficient data for %s. Not included in final MTS."%user)
    return umts, tsum


# Interpolates all features to the highest sampling rate
def resampleFeatureMTS(umts, features, rejectIncomplete = False):   
    if rejectIncomplete:
        print("Rejecting incomplete features")
        umts_validated = {}
        for u in umts: 
            mts = umts[u]
            if(len(mts) != len(features)):
                print("Insufficient feature data for %s. Not included in final MTS."%u)
                continue
            else:
                umts_validated[u] = mts
        umts = umts_validated  
    
    user_bounds = {}
    for u in umts:
        mts = umts[u]
        
        max_t = len(max(mts, key=lambda f: len(f)))
        fmts = np.zeros((len(mts), max_t))
        
        # print('User:', u, '\tFeats: ', len(mts), '\tDatapoints: ', max_t)
        user_bounds[u] = max_t

        # Not enough feature data
        for i, f in enumerate(mts):
            if(len(f) < max_t):
                oldf = len(f)
                told = np.linspace(0, 1, len(f))
                tnew = np.linspace(0, 1, max_t)
                f = np.interp(tnew, told, f)
            fmts[i, :] = f
        umts[u] = fmts
    return umts, user_bounds

################
# PANDAS TOOLS #
################

# Converts MTS matrices to and from user-readable pandas DataFrames

def mts2df(mts, users, features):
    assert mts[users[0]].shape[0] == len(features)

    data = {}

    for u in users:
        for i in range(len(features)):
            data[(u, features[i])] = pd.Series(mts[u][i])

    return pd.DataFrame(data).transpose()

def df2mts(mts_df):
    users = list(mts_df.index.levels[0])
    feats = list(mts_df.index.levels[1])

    F = len(feats)

    mts = {}

    for u in users:
        N = len(mts_df.loc[u, feats[0]].dropna())
        arr = np.zeros((F, N))

        for i in range(F):
            arr[i] = mts_df.loc[u, feats[i]].dropna().as_matrix()

        mts[u] = arr

    return mts, users, feats
