import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib as mpl
mpl.rcParams['axes.unicode_minus']=False
mpl.rcParams['axes.linewidth'] = 4

import numpy as np
from scipy.cluster.hierarchy import dendrogram, linkage, fcluster
from scipy.ndimage.filters import gaussian_filter1d
import pylab as pl
import matplotlib.gridspec as gridspec
import seaborn as sns
import matplotlib.font_manager as font_manager
import cmocean
import vapeplot

# cmap_name, alpha, perc, which
COLOR_MAP = {
    'motion': [plt.get_cmap('cividis'), 0.9, 25, 'min', 10, 'max'],
    'emotion': [cmocean.cm.thermal, 0.8, 20, 'both'],
    'jupyter': [cmocean.cm.rain_r, 0.8, 20, 'both']
}

def plot_chromatogram(cgram, users):
    sns.set_style('white')
    plt.figure(figsize=(20, 10))
    t = cgram.mts.feat_class
    plt.suptitle("{t} Process Chromatogram".format(t=t.title()), name='CMU Bright', size=38, weight='bold')

    plt.title("(L={}, cull={}, M={}, W={}, Δ(raw)={:.2f}, Δ(smooth)={:.2f})".\
                format(cgram.mts.L, cgram.codebook.cull, cgram.codebook.M, cgram.smoothing_window, 
                cgram.d_raw, cgram.d_smooth), name='CMU Bright', size=24, y=1.01, weight='bold')
    ax = plt.gca()

    data = cgram.chromatogram

    if cgram.rendered:
        data = cgram.reorder_colors(data)
        values = cgram.reorder_colors(list(range(cgram.codebook.K + 1)))
        print('reordering colors: {}'.format(values))
    else:
        values = list(range(cgram.codebook.K + 1))

    cm_props = COLOR_MAP[t]
    cm = cm_props[0]
    cm = cmocean.tools.lighten(cm, cm_props[1])
    cm = cmocean.tools.crop_by_percent(cm, cm_props[2], which=cm_props[3], N=None)

    if len(cm_props) == 6:
        cm = cmocean.tools.crop_by_percent(cm, cm_props[4], which=cm_props[5], N=None)

    im = plt.imshow(data, aspect='auto', cmap=cm)
    colors = [im.cmap(im.norm(value)) for value in values]

    # https://stackoverflow.com/questions/25482876/how-to-add-legend-to-imshow-in-matplotlib
    perc = cgram.get_codeword_distribution()
    len_stats = cgram.get_length_stats()
    patches = [mpatches.Patch(color=colors[0], label="Codeword 0")] # don't display % for null codeword

    if cgram.clustered:
        patches += [mpatches.Patch(color=colors[i], label="Codeword {} ({:.2f}%)\nδ={:.2f}%, μ={:.2f}, σ={:.2f}"\
            .format(i, 100*perc[i], 100*cgram.freq_diff[i-1], len_stats[i][0], len_stats[i][1])) \
                                for i in range(1, cgram.codebook.K + 1)]
    else:
        patches += [mpatches.Patch(color=colors[i], label="Codeword {} ({:.2f}%)"\
            .format(i, 100*perc[i])) for i in range(1, cgram.codebook.K + 1)]
    
    ax.set_yticks(list(range(len(users))))
    ax.set_yticklabels(users)
    ax.axhline(10.5, color='k', linewidth=4)
    plt.setp(ax.get_yticklabels(), name='CMU Bright', size=24)
    plt.ylabel('User', name='CMU Bright', size=25, weight='bold', labelpad=15)
    plt.setp(ax.get_xticklabels(), name='CMU Bright', size=15, weight='bold')
    font = font_manager.FontProperties(family='CMU Bright',
                                   weight='bold', size=20)
    plt.legend(handles=patches, bbox_to_anchor=(1.01, 1), loc=2, borderaxespad=0., borderpad=0, frameon=False, prop=font)
    plt.show()

JUP_LABELS = {
    'execute': 'exec',
    'mouseevent': 'mouse',
    'notebooksaved': 'save',
    'select': 'select',
    'textchunk': 'text'
}

def vis_codewords(codebook):
    word_shape = codebook.mts.word_shape
    F = word_shape[0]
    W = word_shape[1]

    # SETUP
    sns.reset_orig()
    sns.set_style('whitegrid')
    mpl.rcParams['axes.unicode_minus']=False

    K = codebook.K
    if K > 3: # if K > 3: fix 2 rows, fill columns in
        if K % 2 == 1:
            cols = K // 2 + 1
        else:
            cols = K // 2
        rows = 2
    else:
        cols = K
        rows = 1
    
    fig = plt.figure(figsize=(7 * cols, 4 * rows))
    outer = gridspec.GridSpec(rows, cols, wspace=0.1, hspace=0.25)
    
    title = codebook.mts.feat_class
    cm = COLOR_MAP[title][0]
    cm = cmocean.tools.lighten(cm, COLOR_MAP[title][1])
    cm = cmocean.tools.crop_by_percent(cm, COLOR_MAP[title][2], which=COLOR_MAP[title][3], N=None)

    values = list(range(codebook.K + 1))
    if hasattr(codebook, 'reorder_colors'):
        values = codebook.reorder_colors(values)

    colors = [cm((values[i]) / K) for i in range(K+1)]
    if rows == 1:
        y = 1.1
    else:
        y = 1
    fig.suptitle("{} Codebook".format(title.title()), name='CMU Bright', size=30, weight='bold', y=y, horizontalalignment='center')

    for i, cw in codebook.codebook.items():
        inner = gridspec.GridSpecFromSubplotSpec(F, 1, subplot_spec=outer[i-1], hspace=0.03)
        cw = cw.reshape((F, -1))

        for j in range(F):
            x = cw[j]
            ax = plt.Subplot(fig, inner[j])
            
            ax.set_ylim(-3, 3)
            ax.set_yticks([-3, -1.5, 0, 1.5, 3])
            ax.set_xlim(0, W-1)

            if title=='emotion':
                ax.set_xticks([0, 8, 16, 24, 32])
                ax.set_xticklabels([0, 1, 2, 3, 4])
            elif title=='jupyter':
                ax.set_xticks([0, 12, 24, 36, 48])
                ax.set_xticklabels([0, 2, 4, 6, 8])
            elif title=='kinnunen':
                ax.set_xticks(list(range(10)))

            plt.setp(ax.get_yticklabels(), visible=False)
            
            x_smooth = gaussian_filter1d(x, sigma=0.75)
            ax.plot(x, color='k', alpha=0.3, linewidth=4)
            ax.plot(x_smooth, color='k', alpha=.7, linewidth=2)
            
            ax.axvspan(0, W, facecolor=colors[i], alpha=0.8)
            
            plt.setp(ax.get_yticklabels(), name='CMU Bright', size=12)
            
            if j != F-1:
                plt.setp(ax.get_xticklabels(), visible=False)
            else:
                plt.setp(ax.get_xticklabels(), name='CMU Bright', size=22);
            fig.add_subplot(ax)

def plot_user(cgram, user, sigma, ylim=None):
    sns.reset_orig()

    mpl.rcParams['axes.linewidth'] = 0
    mpl.rcParams['axes.unicode_minus']=False

    F = len(cgram.mts.features)
    B = len(cgram.mts[user][1])

    B = int(4 * 19.5 * 60)

    plt.figure(figsize=(20, 2.*F))
    t = cgram.mts.feat_class
    plt.suptitle("User {} {} Chromatogram".format(user, t.title()), name='CMU Bright', size=30, weight='bold', y=1.02)

    plt.subplots_adjust(hspace=0.4)
    plt.margins(0)

    axs = []
    for i in range(F):
        ax = plt.subplot(F, 1, i+1)

        axs.append(ax)
        ax.set_xlim(0, B-1)
        x_raw = cgram.mts[user][i][:B]

        if type(sigma) is list:
            s = sigma[i]
        else:
            s = sigma

        x_smooth = gaussian_filter1d(x_raw, sigma=s)
        ax.plot(x_raw, color='k', alpha=0.2, linewidth=3)
        ax.plot(x_smooth, color='k', alpha=1, linewidth=1.5)

        ax.yaxis.grid(False)
        if ylim:
            ax.set_ylim(ylim[i])
            if i == F-1:
                ax.set_yticks([ylim[i][1] / 2, ylim[i][1]])
            else:
                ax.set_yticks([0, ylim[i][1] / 2, ylim[i][1]])

        label = cgram.mts.features[i]
        if t == 'jupyter':
            label = JUP_LABELS[label]
        
        pad = [18, 15, 8, 12, 8]
        ax.set_ylabel(label, name='CMU Bright', size=26, labelpad=pad[i])

        if i == F-1:
            pass
        else:
            plt.setp(ax.get_xticklabels(), visible=False)

        plt.setp(ax.get_yticklabels(), name='CMU Bright', size=15)

    window_size = cgram.mts.word_shape[1]

    K = cgram.codebook.K
    cm = COLOR_MAP[t][0]
    cm = cmocean.tools.crop_by_percent(cm, COLOR_MAP[t][2], which=COLOR_MAP[t][3], N=None)

    values = list(range(K + 1))
    if cgram.rendered:
        values = cgram.reorder_colors(values)

    colors = [cm((values[i]) / K) for i in range(K+1)]

    uid = cgram.users.index(user)
    codes = cgram.chromatogram[uid]

    for i in range(len(codes)):
        cw = int(codes[i])
        if cw == 0:
            break
        
        for ax in axs:
            start = i * (window_size // 2)
            stop = start + window_size
            ax.axvspan(start, stop, 
                       facecolor=colors[cw], edgecolor=None, alpha=0.7)
        
def plot_freq_diff(cgram):
    sns.set_style('whitegrid')
    fig = plt.figure(figsize=(8, 4.5))
    plt.title("Codeword Frequency ", name='CMU Bright', size=30, weight='bold', y=1.02)

    title = cgram.mts.feat_class
    cm = COLOR_MAP[title][0]
    cm = cmocean.tools.lighten(cm, COLOR_MAP[title][1])
    cm = cmocean.tools.crop_by_percent(cm, COLOR_MAP[title][2], which=COLOR_MAP[title][3], N=None)

    K = cgram.codebook.K
    values = list(range(K + 1))
    values = cgram.reorder_colors(values)

    colors = [cm((values[i]) / K) for i in range(K+1)]

    freq = cgram._freq_diff
    bar_list = plt.barh(range(K, 0, -1), freq)
    for i in range(K):
        bar_list[i].set_color(colors[i])

    ax = fig.gca()
    ax.yaxis.grid(False)
    ax.set_xlim([-.75, .75])
    ax.set_xticks([-.75, -.5, -.25, 0, .25, .5, .75])
    ax.set_yticks(list(range(1, K+1)))

    plt.setp(ax.get_xticklabels(), name='CMU Bright', size=14, weight='bold')
    plt.setp(ax.get_yticklabels(), name='CMU Bright', size=14, weight='bold');

# adapted from https://joernhees.de/blog/2015/08/26/scipy-hierarchical-clustering-and-dendrogram-tutorial/
def fancy_dendrogram(*args, **kwargs):
    max_d = kwargs.pop('max_d', None)
    if max_d and 'color_threshold' not in kwargs:
        kwargs['color_threshold'] = max_d
    annotate_above = kwargs.pop('annotate_above', 0)

    ddata = dendrogram(*args, **kwargs)

    if not kwargs.get('no_plot', False):
        plt.title('Hierarchical Clustering Dendrogram (truncated)')
        plt.xlabel('Sample index or (cluster size)')
        plt.ylabel('Distance')
        for i, d, c in zip(ddata['icoord'], ddata['dcoord'], ddata['color_list']):
            x = 0.5 * sum(i[1:3])
            y = d[1]
            if y > annotate_above:
                plt.plot(x, y, 'o', c=c)
                plt.annotate("%.3g" % y, (x, y), xytext=(0, -5),
                             textcoords='offset points',
                             va='top', ha='center')
        ax = plt.gca()
        for tick in ax.xaxis.get_major_ticks():
            tick.label.set_fontsize(pl.rcParams['xtick.labelsize']) 
        if max_d:
            plt.axhline(y=max_d, c='grey', lw=2, linestyle='dashed')

    return ddata