% ************* FONCTION : ofdm_demod() ************* %
% Cette fonction fait la demodulation des données reçues

function [decoded_symb, decoded_phase] = ofdm_demod(symb_rx, ifft_size, carriers, conj_carriers,guard_time, symb_size, word_size, last, unpad, fig)

symb_period = ifft_size + guard_time;
% reshape de la forme spectrale temporelle en segments pour la FFT
symb_rx_matrix = reshape(symb_rx(1:...
(symb_period*floor(length(symb_rx)/symb_period))), ...
symb_period, floor(length(symb_rx)/symb_period));

% ------------------------------------------ %
% ##### enlève le préfixe cyclique ##### %
% ------------------------------------------ %
symb_rx_matrix = symb_rx_matrix(guard_time+1:symb_period,:);

% ------------------------------------------------------------------ %
% ### prend la FFT de l'onde temporelle reçue pour obtenir un spectre de données ### %
% ------------------------------------------------------------------ %
rx_spectrum_matrix = fft(symb_rx_matrix)';
% trace les diagrammes de phase et de magnitude du spectre de fréquences reçu
if fig==1
    limt = 1.1*max(abs(reshape(rx_spectrum_matrix',1,...
    size(rx_spectrum_matrix,1)*size(rx_spectrum_matrix,2))));
    figure(5)
    stem(0:ifft_size-1, abs(rx_spectrum_matrix(ceil...
    (size(rx_spectrum_matrix,1)/2),1:ifft_size)),'b*-')
    grid on
    axis ([0 ifft_size -limt limt])
    ylabel('Magnitude')
    xlabel('FFT Bin')
    title('Magnitude du spectre OFDM reçu')
    figure(6)
    plot(0:ifft_size-1, (180/pi)*angle(rx_spectrum_matrix(ceil...
    (size(rx_spectrum_matrix,1)/2),1:ifft_size)'), 'go')
    hold on
    stem(carriers-1, (180/pi)*angle(rx_spectrum_matrix(2,carriers)'),'b*-')
    stem(conj_carriers-1, (180/pi)*angle(rx_spectrum_matrix(ceil...
    (size(rx_spectrum_matrix,1)/2),conj_carriers)),'b*-')
    axis ([0 ifft_size -200 +200])
    grid on
    ylabel('Phase (degrés)')
    xlabel('FFT Bin')
    title('Phase du spectre OFDM reçu')
    
end

% ----------------------------------------------------------------- %
% ### extrait les colonnes de données sur les symboles de l'IFFT de toutes les sous-porteuses ### %
% ----------------------------------------------------------------- %

rx_spectrum_matrix = rx_spectrum_matrix(:,carriers);

% --------------------------------------------- %
% ### démodulation PSK (Phase Shift Keying) ### %
% --------------------------------------------- %
% calcul des phases correspondantes du spectre complexe

rx_phase = angle(rx_spectrum_matrix)*(180/pi);

% valeur abs des phases
rx_phase = rem((rx_phase+360), 360);

% tracé polaire des symboles reçus

if fig==1
    figure(7)
    rx_mag = abs(rx_spectrum_matrix(ceil(size(rx_spectrum_matrix,1)/2),:));
    polar(rx_phase(ceil(size(rx_spectrum_matrix,1)/2),:)*(pi/180), ...
    rx_mag, 'bd')
    title('Phases reçues')
    
end

% --------------------------------- %
% ##### Décodage différentiel ##### %
% --------------------------------- %

% inversement du codage différentiel
decoded_phase = diff(rx_phase);

% valeurs abs
decoded_phase = rem((decoded_phase+360), 360);

% "parellel to serial"
decoded_phase = reshape(decoded_phase',1, size(decoded_phase,1)*size(decoded_phase,2));

% classification "phase-to-data"
base_phase = 360/(2^symb_size);

% translation  "phase-to-data"
decoded_symb = floor(rem((decoded_phase/base_phase+0.5),(2^symb_size)));

% obtention des phases décodées pour le calcul des erreurs 
decoded_phase = rem(decoded_phase/base_phase+0.5, ...
(2^symb_size))*base_phase - 0.5*base_phase;

% on enlève les zéros durant la modiulation 
if last==1
    decoded_symb = decoded_symb(1:(length(decoded_symb)-unpad));
    decoded_phase = decoded_phase(1:(length(decoded_phase)-unpad));
    
end

