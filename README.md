<p align='center'>
	<img src="logo.png" alt="logo" width="200" height="250"/>
</p>

# eluent
A tool for conducting hybrid microgenetic analysis with sensor data. Eluent consists of a Python package for data analysis & processing and a Ruby web app interface for post-study qualitative analysis. Eluent accompanies our paper
> Cesar Torres, Matthew Jörke, Emily Hill, Eric Paulos. [Hybrid Microgenetic Analysis: Using Activity Codebooks toIdentify and Characterize Creative Process](link), *Creativity & Cognition 2019*. 

Please refer to the paper for further technical details. 

## Usage
This section gives a brief outline of how to use our package. A full code example (including visualizations) can be found in `example.ipynb`.


### Data Input Format
Eluent expects user input data in the following format:
```
 DATA_ROOT
 ├── UID1
 │   ├── FEAT1.json
 │   ├── FEAT2.json
 │  ...
 │   └── FEATN.json
 ├── UID2
 │   ├── FEAT1.json
 │   ├── FEAT2.json
 │  ...
 │   └── FEATN.json
 ├── UID3
... 
```
`DATA_ROOT` is user specifiable in `eluent/dataset.py`. Each `UID` must be a unique string and feature names must be consistent across users. 

Each JSON file should be structured as
```
{
	"timestamp": 		# start of session (Unix time)
    "sampling_rate": 	# sensor sampling rate in ms
    "data": [...] 		# an array of sensor data sampled every sampling_rate
}
```
Asynchronously sampled data (e.g. Juptyer notebook events) can alternatively be represented as
```
{
    "data": {			
    	"t": [...]		# array of time values (Unix time)
    	"y": [...]		# array of sample values
    }					# --> value y[i] was sampled at time t[i]
}
```

### MTS Matrix Construction
MTS matrix tools are contained in the `MTS` object. Properly formatted input data can be automatically read, time-aligned, normalized, and sampled into windows of size *L*. 

```
mts = dataset.MTS(users, 'jupyter') # construct MTS matrix for juptyer features
L = mts.time2L(8) # determine the window size using the sampling frequency
mts.extract_samples(L, normalize=True); # extract samples and perform per sample normalization
```

### Activity Segmentation Algorithm
The activity segmentation algorithm transforms a multivariate timeseries matrix into a *process chromatogram*. The algorithm consists of three phases: (1) distillation, (2) extraction, and (3) application. The activity segmentation algorithm is contained in the `activity` module. 

First, we must construct a `Codebook` object from our MTS matrix object.

```
codebook = activity.Codebook(mts)
```

##### (1) Distillation
The distillation phase uses an adaptive greedy centers algorithm to reduce the size of the dataset. The `cull_threshold` (ε) controls how many samples are discarded at every step; a higher cull threshold produces fewer samples.
```
codebook.distill(cull_threshold=10)
```
After subsampling, the resulting pruned dataset is hierarchically clustered. This operation is computationally intensive: the cull threshold should be set such that approx. 1000 samples are found. 

##### (2) Extraction
The exatraction phase identifies *K* maximially distinctive codewords by pruning the dendrogram at the *k*-th level. 
```
codebook.extract(K=5)
```

##### (3) Application
Finally, the codebook is applied the original MTS matrix, producing a `Chromatogram` object. 
```
chromatogram = codebook.apply()
```

### Chromatogram Analysis
To generate the full chromatogram, the object must first be *rendered*: rendering applies window smoothing, clusters users based on a given statistic, and recolors the chromatogram based on clustering statistics.
```
chromatogram.render(smoothing_window=3, segment_on='freqs', reorder_colors=True)
```

- `smoothing_window`: controls the kernel size *W* during window smoothing
- `segment_on`: determines which feature vector η users are segmented on
	- `freqs`: codeword frequency vector
	- `logfreqs`: log of codeword frequency vector
	- `markov`: codeword transition matrix
	- `width`: bandwidth mean and standard deviations

#### Statistics & Analysis
The Chromatogram object supports the following methods for codeword analysis. 

| Function Name | Output |
| --- | --- | --- |
| `get_length_stats` | dict from codeword number to (mean bandwidth, bandwidth stddev) |
| `get_codeword_length_distribution` | dict from codeword number to raw list of all bandwidth lengths |
| `get_lengths_per_user` | dict from user to dict of raw bandwidth lengths per codeword |
| `get_markov_model` | dict from user to markov transition matrix |
| `get_freqs_per_user` | dict from user to codeword frequency vector | 


#### Exporting
To export the chromatogram for use in the qualitative analysis web app, time-tracked VTT (subtitle) files are generated for each user's screen capture. 
```
save_path = 'vtt'
prefix = 'jupyter
dataset.save_subtitles(save_path, chromatogram, prefix)
```

### Visualizations
The following methods are supported:
- `Codebook.visualize()`
- `codebook.visualize_linkage()`
- `Chromatogram.visualize()`
- `Chromatogram.plot_user()`
- `Chromatogram.plot_freq_diff()`
- (in development) `Chromatogram.plot_bandwidth_diff()`
- (in development) `Chromatogram.plot_markov_diff()`

See the Jupyter notebook `example.py` for examples of each method. 

Note that all visualizations use the open source [CMU Bright](https://ctan.org/pkg/cm-unicode?lang=en) font. 

<sub><sup>**Logo Attribution**––Binary Code by Taylan Sentürk, Flask by iconsmind.com from the Noun Project</sup></sub>