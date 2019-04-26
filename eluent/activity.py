from glob import glob
import json, datetime, time, os, random, platform, sys

import scipy
from tslearn import metrics as tsm
from matplotlib import colors

from scipy import ndimage, signal
import scipy.spatial.distance as distance
from scipy.spatial.distance import euclidean, pdist, squareform, cdist
from scipy.cluster import hierarchy
from scipy.cluster.hierarchy import dendrogram, linkage, fcluster
from scipy.ndimage.filters import gaussian_filter1d

import numpy as np
from numpy.lib.stride_tricks import as_strided
np.set_printoptions(precision=3, suppress=True)  # suppress scientific float notation

from eluent.dataset import get_file, mts2df, df2mts, MTS
from eluent import visualization
import cmocean

class Codebook:
    """Container class for a Codebook object. Must be constructed from an MTS Object. Contains methods for subsequence clustering and codeword extraction. """
    def __init__(self, mts):
        self.mts = mts
        self.distilled = False
        self.extracted = False

    # Extracts all subsequences and performs hierarchical clustering
    def distill(self, cull_threshold):
        sss = self.mts.samples
        word_shape = self.mts.word_shape
        self.cull = cull_threshold

        # Sample using greedy k-centers clustering
        N = sss.shape[0]
        first_center = random.randint(0, N)
        first_center = N // 2
        seed = sss[first_center]
        code_sample = np.delete(sss, first_center, 0)

        # Construct distance metric
        dtw = make_multivariate_dtw(word_shape)

        self.centers = sample_kcenters(code_sample, [seed], dtw, cull_threshold)
        M = self.centers.shape[0]
        self.M = M
        print('Sampled M={} centers, {:.2f}%% of original N={} sequences'.format(M, (M / N) * 100, N))
        print("--------------------------------------------------")

        # Hierarchical clustering and pruning
        print('Hierarchical clustering...', end='\r')
        self.linkage_matrix = linkage(self.centers, method='complete', metric=dtw)
        print("Generated hierarchical cluster")
        self.distilled = True

    # Extracts K distinctive codewords from the codebook by pruning the dendrogram at the K-th level
    def extract(self, K):
        if not self.distilled:
            print("Must call Codebook.distill() before extract")
            return

        self.K = K
        word_shape = self.mts.word_shape
        dtw = make_multivariate_dtw(word_shape)

        clusters = fcluster(self.linkage_matrix, K, criterion='maxclust')

        # Codeword extraction
        codebook = {}
        for i in range(len(clusters)):
            cluster_id = clusters[i]
            if not cluster_id in codebook:
                codebook[cluster_id] = []
            codebook[cluster_id].append(self.centers[i])


        for i in range(1, K+1):
            print("Codeword {}: Cluster size={}".format(i, len(codebook[i])))

        # Computer centroid
        for k in codebook:
            codeset = np.array(codebook[k])
            dist = np.sum(squareform(distance.pdist(codeset, metric=dtw)), 0)
            clustroid = np.argmin(dist)
            codebook[k] = codeset[clustroid]

        self.codebook = codebook
        self.extracted = True

        self.reorder_colors = lambda x: x
        return codebook

    # Plots a dendrogram
    def visualize_linkage(self, d=0):
        if not self.distilled:
            print("Must call Codebook.distilled() before visualize_linkage")

        return visualization.fancy_dendrogram(self.linkage_matrix, truncate_mode='lastp',
                                            p=12,
                                            leaf_rotation=90.,
                                            leaf_font_size=12.,
                                            show_contracted=True,
                                            annotate_above= 0.4, 
                                            max_d=d)

    # Plots the codebook
    def visualize(self):
        if not self.extracted:
            print("Must call Codebook.extract() before visualize_codewords")

        return visualization.vis_codewords(self)

    # Generates a Chromatogram object by applying the Codebook to the MTS matrix
    def apply(self):
        assert self.extracted, "Must call Codebook.extract() before applying codebook"
        
        return Chromatogram(self.mts, self)

class Chromatogram:
    """Container class for a Chromatogram object. Contains methods for visualizing chromatograms and computing statistics."""
    def __init__(self, mts, codebook):
        self.mts = mts
        self.codebook = codebook
        self.users = self.mts.users
        self.rendered = False

    # Renders the chromatogram by computing the closest codeword to each L-sequence in the original MTS matrix.
    #   - smoothing_window: controls the window size for codeword smoothing
    #   - segment_on: determines how to cluster the user (see segment_users method)
    #   - reorder_colors: whether the most salient colors should be reassigned to codewords with the shortest duration
    def render(self, smoothing_window=0, segment_on='freqs', reorder_colors=True):

        def normalize(word):
            for i in range(word.shape[0]):
                std = np.std(word[i])
                if std == 0:
                    word[i] = word[i] - np.mean(word[i])
                else:
                    word[i] = (word[i] - np.mean(word[i])) / np.std(word[i])
            return word.flatten()

        sss = self.mts.samples
        N = len(sss)
        dtw = make_multivariate_dtw(self.mts.word_shape)

        results = []
        for i in range(N):
            w = normalize(sss[i].reshape(self.mts.word_shape))
            cw_dists = [dtw(cw, w) for cw in self.codebook.codebook.values()]
            results.append(cw_dists)

        bounds = self.mts.bounds
        sizes = []
        for i in range(len(bounds)-1):
            start = bounds[i]
            end = bounds[i+1]
            sizes.append(end-start)
        tn = max(sizes)

        chromatogram = np.zeros((len(bounds) - 1, tn))
        raw = np.zeros((len(bounds) - 1, tn))

        def window_smooth(data, S):
            output = []
            M = len(data)
            for i in range(M):
                min_val = max(i-(S // 2), 0)
                max_val = min(i+(S // 2), M)

                dsum = np.sum(data[min_val:max_val], axis=0)
                most_common = np.argmin(dsum) + 1
                output.append(most_common)
            return np.array(output)

        bounds = self.mts.bounds
        sizes = []
        for i in range(len(bounds)-1):
            start = bounds[i]
            end = bounds[i+1]
            sizes.append(end-start)

        for i in range(len(sizes)):
            data =  np.array(results[bounds[i]:bounds[i+1]])

            if smoothing_window > 0:
                chromatogram[i, :sizes[i]] = window_smooth(data, smoothing_window)

            else:
                chromatogram[i, :sizes[i]] = np.argmin(data, axis=1) + 1

            raw[i, :sizes[i]] = np.argmin(data, axis=1) + 1

        self.chromatogram = chromatogram
        self.raw = raw

        self.smoothing_window = smoothing_window
        self.smoothing_stats()

        print("--------------------------------------------------")
        if reorder_colors:
            self.reorder_colors()

        print("--------------------------------------------------")
        self.segment_users(on=segment_on)
        self.rendered = True

    # Computes smoothing statistics:
    #   - number of transitions (Δ)
    #   - bandwidth mean and std
    def smoothing_stats(self):
        U, T = self.raw.shape

        raw_changes = 0
        smooth_changes = 0
        raw_len = []
        smooth_len = []

        for u in range(U):
            raw_row = self.raw[u]
            smooth_row = self.chromatogram[u]

            last_raw = raw_row[0]
            last_smooth = smooth_row[0]
            max_len_raw = 1
            max_len_smooth = 1

            for i in range(1, len(raw_row)):
                curr_raw = raw_row[i]
                curr_smooth = smooth_row[i]
                if curr_raw == 0:
                    break

                if curr_raw != last_raw:
                    raw_changes += 1

                    raw_len.append(max_len_raw)
                    max_len_raw = 1
                else:
                    max_len_raw += 1

                if curr_smooth != last_smooth:
                    smooth_changes += 1

                    smooth_len.append(max_len_smooth)
                    max_len_smooth = 1
                else:
                    max_len_smooth += 1 

                last_raw = curr_raw
                last_smooth = curr_smooth

        self.d_raw = raw_changes / U
        self.d_smooth = smooth_changes / U

        print("SMOOTHING STATS: Δ_raw={}, Δ_smooth={}, ratio={:.4f}".format(raw_changes, smooth_changes, raw_changes / smooth_changes))
        print("CW LENGTH STATS: μ_raw   ={:.4f}, σ_raw   ={:.4f}\n                 μ_smooth={:.4f}, σ_smooth={:.4f}"\
            .format(np.mean(raw_len), np.std(raw_len), 
                                                                                     np.mean(smooth_len), np.std(smooth_len)))

    def reorder_colors(self):
        len_stats = self.get_length_stats()

        means = [len_stats[i][0] for i in range(1, self.codebook.K+1)]
        print("Bandwidth means: {}".format(means))
        order = np.argsort(means)[::-1]
        order = list(order)
        def reorder(x):
            x = int(x)
            if x == 0:
                return 0
            return order.index(x-1) + 1

        self.reorder_colors = np.vectorize(reorder)
        self.codebook.reorder_colors = np.vectorize(reorder)

        print("New color order: {}".format(order))
        self.color_order = order

    # How to cluster users in the chromatogram
    #   - 'freqs': clusters users based on their codeword frequency vectors
    #   - 'logfreqs': clusters users based on the log of their codeword frequency vectors
    #   - 'markov': clusters users based on their codeword transition matrix
    #   - 'width': clusters users based on their bandwidth mean and stddevs
    def segment_users(self, on='freqs'):
        if on =='freqs':
            freqs = self.get_freqs_per_user()

        elif on == 'logfreqs':
            freqs = self.get_freqs_per_user()
            freqs = np.log(freqs + 1e-12)

        elif on == 'markov':
            K = self.codebook.K
            U = len(self.users)
            markov = self.get_markov_model()

            freqs = np.zeros((U, K*K))

            for i in range(U):
                freqs[i] = markov[self.users[i]].flatten()

        elif on == 'width':
            freqs = self.get_freqs_per_user()
            len_per_user = self.get_lengths_per_user()

            K = self.codebook.K
            U = len(self.users)
            lengths = np.zeros((U, 2*K))

            for i in range(U):
                u = self.users[i]
                for k, l in len_per_user[u].items():
                    if len(l) > 0:
                        l = np.array(l)
                        lmin = np.min(l)
                        lmax = np.max(l)

                        if lmax == lmin:
                            lengths[i, k-1] = np.mean(l) - lmin
                        else:
                            lengths[i, k-1] = (np.mean(l) - lmin) / (lmax - lmin)

                    else:
                        lengths[i, k-1] = 0

        else:
            print("Unknown parameter {}".format(on))

        ordering = self.duo_cluster(freqs, np.array(self.users), 0)
        
        self.users = list(ordering)
        print("New ordering: ", ordering)

        idx = np.argsort(np.argsort(ordering))

        self.clustered = True
        self.chromatogram = self.chromatogram[idx]
        self.raw = self.raw[idx]

    def get_freq_diff(self, u1, u2):
        freqs = self.get_freqs_per_user(ax=1)
        diff = freqs[u1].mean(axis=0) - freqs[u2].mean(axis=0)
        self._freq_diff = diff
        self.freq_diff = abs(diff)

    # Recursive clustering method
    def duo_cluster(self, cbf, group, level):
        tabs = ""
        t = level
        while t > 0:
            tabs = tabs + "\t"
            t = t - 1
            
        print(tabs, group.shape[0], "USERS", group)
        if group.shape[0] <= 2:
            return group
        
        CF = linkage(cbf, method='complete', metric="euclidean")
        clusters = fcluster(CF, 2, criterion='maxclust')
        g1 = np.where(clusters == 1)
        g2 = np.where(clusters == 2)
        if len(g1[0]) == len(group):
            return group
       
        u1 = group[g1]
        u2 = group[g2]

        if level == 0:
            self.get_freq_diff(g1, g2)

        cbf1 = cbf[g1]
        cbf2 = cbf[g2]

        return np.concatenate(np.array([self.duo_cluster(cbf1, u1, level + 1), 
                                        self.duo_cluster(cbf2, u2, level+1)]))


    def get_codeword_distribution(self):
        dist = {i+1: 0 for i in range(self.codebook.K)}

        for row in self.chromatogram:
            for cw in row:
                cw = int(cw)
                if cw == 0:
                    break
                dist[cw] += 1

        total = sum(dist.values())

        for cw in dist.keys():
            dist[cw] /= total

        return dist


    ###########################
    # CHROMATOGRAM STATISTICS #
    ###########################

    def get_length_stats(self):
        len_dict = self.get_codeword_length_distribution()
        stats = {i+1: [] for i in range(self.codebook.K)}

        for cw, lens in len_dict.items():
            if len(lens) > 0:
                stats[cw] = (np.mean(lens), np.std(lens))
            else:
                stats[cw] = (0, 0)
        return stats

    def get_codeword_length_distribution(self):
        lengths = {i+1: [] for i in range(self.codebook.K)}

        K = self.codebook.K

        for i in range(len(self.mts.users)):
            row = self.chromatogram[i]

            last_cw = int(row[0])
            max_len = 1
            for j in range(1, len(row)):
                if row[j] == 0:
                    break

                curr_cw = int(row[j])

                if curr_cw == last_cw:
                    max_len += 1
                else:
                    lengths[last_cw].append(max_len)
                    max_len = 1

                last_cw = curr_cw

        return lengths

    def get_lengths_per_user(self):
        users = self.users
        K = self.codebook.K

        len_per_user = {}

        for i in range(len(users)):
            len_per_cw = {i+1: [] for i in range(K)}

            row = self.chromatogram[i]

            last_cw = int(row[0])
            max_len = 1
            for j in range(1, len(row)):
                if row[j] == 0:
                    break

                curr_cw = int(row[j])

                if curr_cw == last_cw:
                    max_len += 1
                else:
                    len_per_cw[last_cw].append(max_len)
                    max_len = 1

                last_cw = curr_cw

            len_per_user[users[i]] = len_per_cw

        return len_per_user

    def get_markov_model(self):
        markov = {}

        K = self.codebook.K
        users = self.users

        for i in range(len(users)):
            transition_matrix = np.zeros((K, K))
            row = self.chromatogram[i]

            for j in range(len(row) - 1):
                if row[j+1] == 0:
                    break

                curr_cw = int(row[j]) - 1
                next_cw = int(row[j+1]) -1
                transition_matrix[curr_cw, next_cw] += 1

            row_sums = transition_matrix.sum(axis=1) + 1e-12
            transition_matrix = transition_matrix / row_sums[:, np.newaxis]
            markov[users[i]] = transition_matrix

        return markov

    def get_freqs_per_user(self, ax=1):
        K = self.codebook.K
        U = len(self.users)
        freqs = np.zeros((U, K))

        for i in range(U):
            row = self.chromatogram[i]

            for j in range(len(row)):
                cw = int(row[j])
                if cw == 0:
                    break
                else:
                    freqs[i, cw - 1] += 1

        sums = freqs.sum(axis=ax) + 1e-12
        if ax == 1:
            freqs = freqs / sums[:, np.newaxis]
        else:
            freqs = freqs / sums[np.newaxis, :]
        return freqs

    def visualize(self, users=None):
        if users:
            visualization.plot_chromatogram(self, users)
        else:
            visualization.plot_chromatogram(self, self.users)

    def plot_user(self, user, sigma=3, ylim=None):
        visualization.plot_user(self, user, sigma, ylim)

    def plot_freq_diff(self):
        visualization.plot_freq_diff(self)

############
# SAMPLING #
############

def subsequences(a, L):
    n, m = a.shape
    windows = int(m/L)    
    window_range = np.linspace(0, windows-1, (windows-1) * 2 + 1)
    ss = []
    for x in window_range:
        ss.append(a[:, int(x*L):int((x+1)*L)])
    return np.array(ss)

def extract_samples(umts, L):
    sss = np.array([])
    bounds = [0]
    for u in umts: 
        mts = umts[u]
        ss = subsequences(mts, L)
        bounds.append(bounds[-1] + ss.shape[0])
        if sss.shape[0] == 0:
            sss = ss
        else:
            sss = np.concatenate((sss, ss))
    word_shape = sss.shape[-2:]
    sss = sss.reshape(sss.shape[0], -1)
    return sss, bounds, word_shape

def sample_sss(A, n):
    return A[np.random.choice(A.shape[0], n, replace=False), :]


def sample_kcenters(words, kcenters, dist_metric, cull_threshold=100):    
    if len(words) <= 1: 
        return np.array(kcenters)

    sys.stdout.write("\033[K")
    print("Sampling ... (words: {}, centers: {})".format(words.shape[0], len(kcenters)), end='\r')
    
    n = words.shape[0]
    dist = [dist_metric(kcenters[-1], words[i]) for i in range(0, n)]
    dists = np.array(dist)
    
    idx = np.argsort(dists)
    kcenters.append(words[idx[-1]])    
    dists = np.sort(dists)
    cull_at = np.argmax(dists>cull_threshold)
    
    cull_indices = idx[:cull_at]
    cull_indices = np.append(cull_indices, idx[-1])
    words = np.delete(words, cull_indices, 0)
    
    return np.array(sample_kcenters(words, kcenters, dist_metric, cull_threshold))

####################
# DISTANCE METRICS #
####################

def EuclideanDistance(t1, t2):
    return np.sqrt(np.sum((t1-t2)**2))

# Dynamic Time Warping Distance
def DTWDistance(s1, s2):
    # Initialize distance matrix (nxn), pad filling with inf  
    DTW= {}
    n1 = range(len(s1))
    n2 = range(len(s2))
    for i in n1:
        DTW[(i, -1)] = float('inf')
    for i in n2:
        DTW[(-1, i)] = float('inf')
    DTW[(-1, -1)] = 0
    
    # Compute the distances (O(nm) time)
    for i in n1:
        for j in n2:
            dist = (s1[i]-s2[j])**2
            DTW[(i, j)] = dist + min(DTW[(i-1, j)], DTW[(i, j-1)], DTW[(i-1, j-1)])
    return np.sqrt(DTW[len(s1)-1, len(s2)-1])

def DTWDistanceD(t1, t2):
    arr = []
    for i in range(0, t1.shape[0]):
        arr.append(DTWDistance(t1[i], t2[i]))
    return sum(arr)

def DTWDistance2D(t1, t2):
    t1 = t1.reshape(WORD_SHAPE)
    t2 = t2.reshape(WORD_SHAPE)
    arr = []
    for i in range(0, t1.shape[0]):
        arr.append(DTWDistance(t1[i], t2[i]))
    return sum(arr)

def dtw2(a, b, word_shape):
    a = a.reshape(word_shape)
    b = b.reshape(word_shape)
    return tsm.dtw(a, b)

def make_multivariate_dtw(word_shape):
    def dtw(a, b):
        a = a.reshape(word_shape)
        b = b.reshape(word_shape)
        return tsm.dtw(a, b)
    return dtw

###########################
# CHROMATOGRAPHY FUNCTION #
###########################

def distill(mts_df, window_size, cull_threshold, K, return_meta=False):
    # Reformat MTS from pandas df to dict user --> matrix
    mts, users, features = df2mts(mts_df)

    # Compute sample width
    L = time2L(users, mts, window_size)

    # Extract all sequence from MTS
    sss, bounds, word_shape = extract_samples(mts, L)
    N = sss.shape[0]
    print("Extracted N={} sequences with shape (F={}, L={})".format(N, word_shape[0], word_shape[1]))
    print("--------------------------------------------------")

    # Sample using greedy k-centers clustering
    first_center = random.randint(0, N)
    first_center = N // 2
    seed = sss[first_center]
    code_sample = np.delete(sss, first_center, 0)

    # Construct distance metric
    dtw = make_multivariate_dtw(word_shape)

    samples = sample_kcenters(code_sample, [seed], dtw, cull_threshold)
    M = samples.shape[0]
    print('Sampled M={} codewords, {:.2f}%% of original N={} sequences'.format(M, (M / N) * 100, N))
    print("--------------------------------------------------")

    # Hierarchical clustering and pruning
    linkage_matrix = linkage(samples, method='complete', metric=dtw)
    clusters = fcluster(linkage_matrix, K, criterion='maxclust')

    # Codeword extraction
    codebook = {}
    for i in range(len(clusters)):
        cluster_id = clusters[i]
        if not cluster_id in codebook:
            codebook[cluster_id] = []
        codebook[cluster_id].append(samples[i])

    # Computer centroid
    for k in codebook:
        codeset = np.array(codebook[k])
        dist = np.sum(squareform(distance.pdist(codeset, metric=dtw)), 0)
        clustroid = np.argmin(dist)
        codebook[k] = codeset[clustroid]

    print('Extracted {} codewords'.format(K))

    meta = {
        "L": L,
        "window_size": window_size,
        "bounds": bounds,
        "word_shape": word_shape,
        "users": users, 
        "features": features, 
        "subsequences": sss.tolist(),
        "linkage_matrix": linkage_matrix.tolist()
    }

    if return_meta:
        return codebook, meta
    else:
        return codebook

def apply(codebook, mts_df, window_size, smoothing_window=None):
    mts, users, features = df2mts(mts_df)
    # Compute sample width
    L = time2L(users, mts, window_size)

    sss, bounds, word_shape = extract_samples(mts, L)
    dtw = make_multivariate_dtw(word_shape)

    results = []
    for i, window in enumerate(sss):
        codeword = np.argmin([dtw(codeword, window) for codeword in codebook.values()])
        results.append(codeword + 1)

    sizes = []
    for i in range(len(bounds)-1):
        start = bounds[i]
        end = bounds[i+1]
        sizes.append(end-start)
    tn = max(sizes)

    chromatogram = np.zeros((len(bounds) - 1, tn))

    for i in range(len(sizes)):
        data = np.array(results[bounds[i]:bounds[i+1]])
        if smoothing_window:
            raise NotImplementedError
            return None
        else:
            chromatogram[i, :sizes[i]] = data

    return chromatogram

