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
%       background_signal = repet.original(audio_signal,sample_rate);
%       
%
%   REPET (extended)
%       
%       The original REPET can be easily extended to handle varying 
%       repeating structures, by simply applying the method along time, on 
%       individual segments or via a sliding window.
%       
%       background_signal = repet.extended(audio_signal,sample_rate);
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
%   Date
%       07/21/17
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
        function background_signal = original(audio_signal,sample_rate)               
        % REPET (original) (see repet)
        
            %%% Defined parameters
            % Window length in seconds for the STFT (audio stationary 
            % around 40 milliseconds)
            window_duration = 0.040;
            
            % Period range in seconds for the beat spectrum 
            period_range = [1,10];
            
            % Cutoff frequency in Hz for the dual high-pass filter of the
            % foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = 100;
            
            %%% STFT and spectrogram
            % STFT parameters
            [window_length,window_function,step_length] = repet.stftparameters(window_duration,sample_rate);
            
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
            
            %%% Beat spectrum and repeating period
            % Beat spectrum of the mean power spectrograms (squared to 
            % emphasize peaks of periodicitiy)
            beat_spectrum = repet.beatspectrum(mean(audio_spectrogram.^2,3));
            
            % Period range in time frames for the beat spectrum (compensate
            % for the zero-padding at the start in the STFT)
            period_range = ceil((period_range*sample_rate+window_length-step_length)/step_length-0.5);
            
            % Repeating period in time frames given the period range
            repeating_period = repet.period(beat_spectrum,period_range);
            
            %%% Background signal
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filter of the foreground
            cutoff_frequency = ceil(cutoff_frequency*(window_length-1)/sample_rate);                          
            
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
        
        % REPET (extended)
        function background_signal = extended(audio_signal,sample_rate)
        % REPET (extended) (see repet)
            
            %%% Defined parameters
            % Segmentation length and step in seconds
            segment_length = 20;
            segment_step = 10;
            
            % Window length in seconds for the STFT (audio stationary 
            % around 40 milliseconds)
            window_duration = 0.040;
            
            % Cutoff frequency in Hz for the dual high-pass filter of the
            % foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = 100;
            
            %%%
            % Segmentation window length, step, and overlap in samples
            segment_length = round(segment_length*sample_rate);
            segment_step = round(segment_step*sample_rate);
            segment_overlap = segment_length-segment_step;
            
            % STFT parameters
            [window_length,window_function,step_length] = repet.stftparameters(window_duration,sample_rate);
            
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filter of the foreground
            cutoff_frequency = ceil(cutoff_frequency*(window_length-1)/sample_rate);
            
            % Number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            if number_samples < segment_length+segment_step
                
                % Just one segment if the signal is too short
                number_segments = 1;
            else
                
                % Number of segments (the last one could be longer)
                number_segments = 1+floor((number_samples-segment_length)/segment_step);
                
                % Triangular window for the overlapping parts
                segment_window = triang(2*segment_overlap);
            end

            background_signal = zeros(number_samples,number_channels);
            h = waitbar(0,'REPET-WIN');
            
            % Loop over the segments
            for j = 1:number_segments
                if number_segments == 1                                                               % Case one segment
                    xj = audio_signal;
                    segment_length = l;                                                              % Update window length
                else
                    if j < number_segments                                                            % Case first segments
                        xj = audio_signal((1:segment_length)+(j-1)*segment_step,:);
                    elseif j == number_segments                                                       % Case last segment (could be longer)
                        xj = audio_signal((j-1)*segment_step+1:number_samples,:);
                        segment_length = length(xj);                                                 % Update window length
                    end
                end

                Xj = [];
                
                % Loop over the channels
                for channel_index = 1:number_channels
                    
                    % STFT of one channel
                    Xji = stft(xj(:,channel_index),window_function,step_length);
                    Xj = cat(3,Xj,Xji);                                                 % Concatenate the STFTs
                end
                Vj = abs(Xj(1:N/2+1,:,:));                                              % Magnitude spectrogram (with DC component and without mirrored frequencies)
                
                
                
                %%% Beat spectrum and repeating period
                % Beat spectrum of the mean power spectrograms (squared to 
                % emphasize peaks of periodicitiy)
                beat_spectrum = repet.beatspectrum(mean(audio_spectrogram.^2,3));

                % Period range in time frames for the beat spectrum 
                % (compensate for the zero-padding at the start in the 
                % STFT)
                period_range = ceil((period_range*sample_rate+window_length-step_length)/step_length-0.5);

                % Repeating period in time frames given the period range
                repeating_period = repet.period(beat_spectrum,period_range);
                    
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
                
%                 if numel(per) == 1                                                      % If single value
%                     pj = per;                                                           % Defined repeating period in time frames
%                 else
%                     bj = beat_spectrum(mean(Vj.^2,3));                                  % Beat spectrum of the mean power spectrograms (square to emphasize peaks of periodicitiy)
%                     pj = repeating_period(bj,per);                                      % Estimated repeating period in time frames
%                 end
% 
%                 yj = zeros(w,number_channels);
%                 for i = 1:number_channels                                                             % Loop over the channels
%                     Mji = repeating_mask(Vj(:,:,i),pj);                                 % Repeating mask for channel i
%                     Mji(1+(1:cof),:) = 1;                                               % High-pass filtering of the (dual) non-repeating foreground
%                     Mji = cat(1,Mji,flipud(Mji(2:end-1,:)));                            % Mirror the frequencies
%                     yji = istft(Mji.*Xj(:,:,i),win,stp);                                % Estimated repeating background
%                     yj(:,i) = yji(1:segment_length);                                                 % Truncate to the original mixture length
%                 end
              
                
                % Case one segment
                if number_segments == 1
                    background_signal = yj;
                else
                    if j == 1                                                           % Case first segment
                        background_signal(1:segment_length,:) = background_signal(1:segment_length,:) + yj;
                    elseif j <= m                                                       % Case last segments
                        background_signal((1:segment_overlap)+(j-1)*segment_step,:) ...                                          % Half windowing of the overlap part of y on the right
                            = background_signal((1:segment_overlap)+(j-1)*segment_step,:).*repmat(segment_window((1:segment_overlap)+segment_overlap),[1,number_channels]);
                        yj(1:segment_overlap,:) ...                                                   % Half windowing of the overlap part of yj on the left
                            = yj(1:segment_overlap,:).*repmat(segment_window(1:segment_overlap),[1,number_channels]);
                        background_signal((1:segment_length)+(j-1)*segment_step,:) = background_signal((1:segment_length)+(j-1)*segment_step,:) + yj;
                    end
                end
                waitbar(j/m,h);
            end
            close(h)
        end
        
        % Adaptive REPET
        function background_signal = adaptive(audio_signal,sample_rate)
        % Adaptive REPET (see repet)
            
            background_signal = 0*audio_signal*sample_rate;
            
        end
        
        % REPET-SIM (with self-similarity matrix)
        function background_signal = sim(audio_signal,sample_rate)
            
            background_signal = 0*audio_signal*sample_rate;
            
        end
        
    end
    
    % Methods (access from methods in class of subclasses and does not 
    % depend on a object of the class)
    methods (Access = protected, Hidden = true, Static = true)
        
        % STFT parameters
        function [window_length,window_function,step_length] = stftparameters(window_duration,sample_rate)
            
            % Window length in samples (power of 2 for fast FFT)
            window_length = 2.^nextpow2(window_duration*sample_rate);
            
            % Window function (even window length and 'periodic' Hamming 
            % window for constant overlap-add)
            window_function = hamming(window_length,'periodic');
            
            % Step length (half the window length for constant overlap-add)
            step_length = window_length/2;
            
        end
        
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
            autocorrelation_matrix = autocorrelation_matrix(1:number_points,:);
            
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
        
        % Repeating period for REPET (simple approach)
        function repeating_period = period(beat_spectrum,period_range)
            
            % The repeating period is the index of the maximum value in the
            % beat spectrum given the period range (it does not take into 
            % account lag 0 and should be shorter than one third of the 
            % signal length since the median needs at least three segments)
            [~,repeating_period] = max(beat_spectrum(period_range(1)+1:min(period_range(2),floor(length(beat_spectrum)/3))));
            
            % Re-adjust the index
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
