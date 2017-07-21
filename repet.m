% REpeating Pattern Extraction Technique (REPET) class
%   
%   Repetition is a fundamental element in generating and perceiving 
%   structure. In audio, mixtures are often composed of structures where a 
%   repeating background signal is superimposed with a varying foreground 
%   signal (e.g., a singer overlaying varying vocals on a repeating 
%   accompaniment or a varying speech signal mixed up with a repeating 
%   background noise). On this basis, we present the REpeating Pattern 
%   Extraction Technique (REPET), a simple approach for separating the 
%   repeating background from the non-repeating foreground in an audio 
%   mixture. The basic idea is to find the repeating elements in the 
%   mixture, derive the underlying repeating models, and extract the 
%   repeating  background by comparing the models to the mixture. Unlike 
%   other separation approaches, REPET does not depend on special 
%   parameterizations, does not rely on complex frameworks, and does not 
%   require external information. Because it is only based on repetition, 
%   it has the advantage of being simple, fast, blind, and therefore 
%   completely and easily automatable.
%   
%   
%   REPET (original)
%       
%       The original REPET aims at identifying and extracting the repeating 
%       patterns in an audio mixture, by estimating a period of the 
%       underlying repeating structure and modeling a segment of the 
%       periodically repeating background.
%       
%       background_signal = repet.original(audio_signal,sample_rate,repeating_period);
%       
%   
%   Adaptive REPET
%   
%       The original REPET works well when the repeating background is 
%       relatively stable (e.g., a verse or the chorus in a song); however, 
%       the repeating background can also vary over time (e.g., a verse 
%       followed by the chorus in the song). The adaptive REPET is an 
%       extension of the original REPET that can handle varying repeating 
%       structures, by estimating the time-varying repeating periods and 
%       extracting the repeating background locally, without the need for 
%       segmentation or windowing.
%       
%       background_signal = repet.adaptive(audio_signal)
%       
%   
%   REPET-SIM (with self-similarity matrix)
%       
%       The REPET methods work well when the repeating background has 
%       periodically repeating patterns (e.g., jackhammer noise); however, 
%       the repeating patterns can also happen intermittently or without a 
%       global or local periodicity (e.g., frogs by a pond). REPET-SIM is a 
%       generalization of REPET that can also handle non-periodically 
%       repeating structures, by using a similarity matrix to identify the 
%       repeating elements.
%       
%       background_signal = repet.sim(audio_signal)
%   
%   
%   See also http://zafarrafii.com/repet.html
%   
%   
%   Author
%       Zafar Rafii
%   
%   
%   References
%       Zafar Rafii, Antoine Liutkus, and Bryan Pardo. "REPET for 
%       Background/Foreground Separation in Audio," Blind Source 
%       Separation, chapter 14, pages 395-411, Springer Berlin Heidelberg, 
%       2014.
%       
%       Zafar Rafii and Bryan Pardo. "Audio Separation System and Method," 
%       US20130064379 A1, US 13/612,413, March 14, 2013.
%       
%       Zafar Rafii and Bryan Pardo. "REpeating Pattern Extraction 
%       Technique (REPET): A Simple Method for Music/Voice Separation," 
%       IEEE Transactions on Audio, Speech, and Language Processing, volume 
%       21, number 1, pages 71-82, January, 2013.
%       
%       Zafar Rafii and Bryan Pardo. "Music/Voice Separation using the 
%       Similarity Matrix," 13th International Society on Music Information 
%       Retrieval, Porto, Portugal, October 8-12, 2012.
%       
%       Antoine Liutkus, Zafar Rafii, Roland Badeau, Bryan Pardo, and Ga�l 
%       Richard. "Adaptive Filtering for Music/Voice Separation Exploiting 
%       the Repeating Musical Structure," 37th International Conference on 
%       Acoustics, Speech and Signal Processing,Kyoto, Japan, March 25-30, 
%       2012.
%       
%       Zafar Rafii and Bryan Pardo. "A Simple Music/Voice Separation 
%       Method based on the Extraction of the Repeating Musical Structure," 
%       36th International Conference on Acoustics, Speech and Signal 
%       Processing, Prague, Czech Republic, May 22-27, 2011.

classdef repet
    
    % Methods (unresctricted access and does not depend on a object of the
    % class)
    methods (Access = public, Static = true)
        
        % REPET (original)
        function background_signal = original(audio_signal,sample_rate,repeating_period)
            
            % Default repeating period range in seconds
            if nargin < 3
                repeating_period = [1,min(10,(length(audio_signal)/sample_rate)/3)];
            end                     
            
            %%% STFT parameters
            % Window length in seconds (audio stationary around 40 
            % milliseconds)
            window_duration = 0.040;
            
            % Window length in samples (power of 2 for fast FFT)
            window_length = 2.^nextpow2(window_duration*sample_rate);
            
            % Window function (even window length and 'periodic' Hamming 
            % window for constant overlap-add)
            window_function = hamming(window_length,'periodic');
            
            % Step length (half the window length for constant overlap-add)
            step_length = window_length/2;
            
            %%% STFT and spectrogram
            % Number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Initialize the STFT
            audio_stft = [];
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % STFT of one channel
                audio_stft1 = repet.stft(audio_signal(:,channel_index),window_function,step_length);
                
                % Concatenate the STFTs
                audio_stft = cat(3,audio_stft,audio_stft1);
            end
            
            % Magnitude spectrogram (with DC component and without mirrored 
            % frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            %%% Repeating period
            % Repeating period in time frames (compensated for the 
            % zero-padding at the start in the STFT)
            repeating_period = ceil((repeating_period*sample_rate+window_length-step_length)/step_length-0.5);
            
            % If range of two values instead of single value
            if numel(repeating_period) == 2
                % Beat spectrum of the mean power spectrograms (squared to 
                % emphasize peaks of periodicitiy)
                beat_spectrum = repet.beatspectrum(mean(audio_spectrogram.^2,3));
                
                keyboard
                
                % Estimated repeating period in time frames
                repeating_period = repet.period(beat_spectrum,repeating_period);
            end
            
            %%% Background signal
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filtering of the foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = ceil(100*(window_length-1)/sample_rate);                          
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % Repeating mask for one channel
                repeating_mask = repet.mask(audio_spectrogram(:,:,channel_index),repeating_period);
                
                % High-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency+1,:) = 1;
                
                % Mirror the frequency channels for the STFT
                repeating_mask = cat(1,repeating_mask,flipud(repeating_mask(2:end-1,:)));
                
                % Estimated repeating background for one channel
                background_signal1 = repet.istft(repeating_mask.*audio_stft(:,:,channel_index),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,channel_index) = background_signal1(1:number_samples);
            end
            
        end
        
%         % Adaptive REPET
%         function adaptive
%             
%         end
%         
%         % REPET-SIM (with self-similarity matrix)
%         function sim
%             
%         end
        
    end
    
    % Methods (access from methods in class of subclasses and does not 
    % depend on a object of the class)
    methods (Access = protected, Static = true)

        % Short-Time Fourier Transform (STFT) (with zero-padding at the 
        % edges)
        function audio_stft = stft(audio_signal,window_function,step_length)
            
            % Number of samples
            number_samples = length(audio_signal);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of time frames
            number_times = ceil((window_length-step_length+number_samples)/step_length);
            
            % Zero-padding at the start and end to center the windows 
            audio_signal = [zeros(window_length-step_length,1);audio_signal; ...
                zeros(number_times*step_length-number_samples,1)];
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times);
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Window the signal
                sample_index = step_length*(time_index-1);
                audio_stft(:,time_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index).*window_function;
                
            end
            
            % Fourier transform of the frames
            audio_stft = fft(audio_stft);
            
        end
        
        % Inverse Short-Time Fourier Transform (ISTFT)
        function audio_signal = istft(audio_stft,window_function,step_length)
            
            % Number of time frames
            [~,number_times] = size(audio_stft);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of samples for the signal
            number_samples = (number_times-1)*step_length+window_length;
            
            % Initialize the signal
            audio_signal = zeros(number_samples,1);
            
            % Inverse Fourier transform of the frames and real part to 
            % ensure real values
            audio_stft = real(ifft(audio_stft));
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Inverse Fourier transform of the signal (normalized 
                % overlap-add if proper window and step)
                sample_index = step_length*(time_index-1);
                audio_signal(1+sample_index:window_length+sample_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index)+audio_stft(:,time_index); 
            end
            
            % Remove the zero-padding at the start and the end
            audio_signal = audio_signal(window_length-step_length+1:number_samples-(window_length-step_length));
            
            % Un-window the signal (just in case)
            audio_signal = audio_signal/sum(window_function(1:step_length:window_length));  
            
        end
        
        % Autocorrelation using the Wiener�Khinchin theorem (faster than 
        % using xcorr)
        function autocorrelation_matrix = acorr(data_matrix)
            
            % Each column represents a data vector
            [number_points,number_frames] = size(data_matrix);
            
            % Zero-padding to twice the length for a proper autocorrelation
            data_matrix = [data_matrix;zeros(number_points,number_frames)];
            
            % Power Spectral Density (PSD): PSD(X) = fft(X).*conj(fft(X))
            data_matrix = abs(fft(data_matrix)).^2;
            
            % Wiener�Khinchin theorem: PSD(X) = fft(acorr(X))
            autocorrelation_matrix = ifft(data_matrix); 
            
            % Discarde the symmetric part
            autocorrelation_matrix(1:number_points,:) = [];
            
            % Unbiased autocorrelation (lag 0 to number_points-1)
            autocorrelation_matrix = bsxfun(@rdivide,autocorrelation_matrix,(number_points:-1:1)');
            
        end
        
        % Beat spectrum using the autocorrelation
        function beat_spectrum = beatspectrum(audio_spectrogram)
            
            % Autocorrelation of the frequency channels
            beat_spectrum = repet.acorr(audio_spectrogram');
            
            % Mean over the frequency channels
            beat_spectrum = mean(beat_spectrum,2);
            
        end
        
        % Repeating period for REPET
        function repeating_period = period(beat_spectrum,period_range)
            
            % Discard lag 0
            beat_spectrum(1) = [];
            
            % Index of the maximum value in the beat spectrum for the 
            % period range
            [~,repeating_period] = max(beat_spectrum(period_range(1):period_range(2)));
            
            % Re-adjust index
            repeating_period = repeating_period+period_range(1);
            
        end
        
        % Repeating mask for REPET
        function repeating_mask = mask(audio_spectrogram,repeating_period)
            
            % Number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Number of repeating segments, including the last partial one
            number_segments = ceil(number_times/repeating_period);
            
            % Pad the audio spectrogram to have an integer number of 
            % segments
            audio_spectrogram = [audio_spectrogram,nan(number_frequencies,number_segments*repeating_period-number_times)];
            
            % Reshape the audio spectrogram for the columns to represent 
            % the segments
            audio_spectrogram = reshape(audio_spectrogram,[number_frequencies*repeating_period,number_segments]);
            
            % Derive the repeating segment by taking the median over the 
            % segments, ignoring the nan parts
            repeating_segment = [median(audio_spectrogram(1:number_frequencies*(number_times-(number_segments-1)*repeating_period),1:number_segments),2); ... 
                median(audio_spectrogram(number_frequencies*(number_times-(number_segments-1)*repeating_period)+1:number_frequencies*repeating_period,1:number_segments-1),2)];
            
            % Derive the repeating spectrogram by making sure it has less 
            % energy than the audio spectrogram
            repeating_spectrogram = bsxfun(@min,audio_spectrogram,repeating_segment);
            
            % Derive the repeating mask by normalizing the repeating 
            % spectrogram by the audio spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);
            
            % Reshape the repeating mask
            repeating_mask = reshape(repeating_mask,[number_frequencies,number_segments*repeating_period]);
            
            % Truncate the repeating mask to the orignal number of time 
            % frames
            repeating_mask = repeating_mask(:,1:number_times);
            
        end
        
    end
    
end
