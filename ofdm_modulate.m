%FONCTION : ofdm_modulation()
%Cette fonction s'occupe de la modulation des données avant la transmission

function signal_tx = ofdm_modulate(data_tx, ifft_size, carriers,conj_carriers, carrier_count, symb_size, guard_time, fig)

% symboles par sous-porteuses pource train
carrier_symb_count = ceil(length(data_tx)/carrier_count);

% ajoute des zéros aux données avec une longueur qui n'est pas un multiple du nombre de sous-porteuses
if length(data_tx)/carrier_count ~= carrier_symb_count,padding = zeros(1, carrier_symb_count*carrier_count);
    
    padding(1:length(data_tx)) = data_tx;
    data_tx = padding;
    
end
% série vers parallele: chaque colonne représente une sous-porteuse
data_tx_matrix = reshape(data_tx, carrier_count, carrier_symb_count)';

% --------------------------------- %
% ##### Encodage différentiel ##### % 
% --------------------------------- %


carrier_symb_count = size(data_tx_matrix,1) + 1;
diff_ref = round(rand(1, carrier_count)*(2^symb_size)+0.5);

data_tx_matrix = [diff_ref; data_tx_matrix];

for k=2:size(data_tx_matrix,1)
    data_tx_matrix(k,:) = rem(data_tx_matrix(k,:)+data_tx_matrix(k-1,:), 2^symb_size);
end

% ------------------------------------------ %
% ## modulation PSK (Phase Shift Keying) ### %
% ------------------------------------------ %
% conversion des données en complexes:
% Amplitudes: 1; Phase: conversion depuis les données en utilisant un
% "mappage par constellation" (constellation mapping)

[X,Y] = pol2cart(data_tx_matrix*(2*pi/(2^symb_size)),ones(size(data_tx_matrix)));
complex_matrix = X + i*Y;

% ##### assigne les sorties de l'IFFT aux sous-porteuses ##### %
% ------------------------------------------------------------ %
spectrum_tx = zeros(carrier_symb_count, ifft_size);
spectrum_tx(:,carriers) = complex_matrix;
spectrum_tx(:,conj_carriers) = conj(complex_matrix);

% La Figure(1) et la Figure(2) montrent toutes les deux les sous-porteuses OFDM sortant de l'IFFT

if fig==1
    figure(1)
    stem(1:ifft_size, abs(spectrum_tx(2,:)),'b*-')
    grid on
    axis ([0 ifft_size -0.5 1.5])
    ylabel('Aamplitude des données PSK')
    xlabel('IFFT Bin')
    title('sous-porteuses OFDM pour une IFFT bins désignée')
    figure(2)
    plot(1:ifft_size, (180/pi)*angle(spectrum_tx(2,1:ifft_size)), 'go')
    hold on
    grid on
    stem(carriers, (180/pi)*angle(spectrum_tx(2,carriers)),'b*-')
    stem(conj_carriers,(180/pi)*angle(spectrum_tx(2,conj_carriers)),'b*-')
    axis ([0 ifft_size -200 +200])
    ylabel('Phase (degrés)')
    xlabel('IFFT Bin')
    title('Phases des données OFDM modulées')
end

% --------------------------------------------------------------- %
% ##### Pour obtenir des ondes dans le domaine temporel depuis le spectre de la forme d'onde en utilisant l'IFFT ##### %
% --------------------------------------------------------------- %

signal_tx = real(ifft(spectrum_tx'))';
% trace une période de symboles du signal temporel qui est finalement transmit

if fig==1
    % signal temporel OFDM (1 période de symboles dans une sous-porteuse)
    limt = 1.1*max(abs(reshape(signal_tx',1,size(signal_tx,1)*size(signal_tx,2))));
    figure (3)
    plot(1:ifft_size, signal_tx(2,:))
    grid on
    axis ([0 ifft_size -limt limt])
    ylabel('Amplitude')
    xlabel('Temps')
    title('Signal temporel OFDM (1 période de symboles dans une sous-porteuse)')
    
    % Signal temporel OFDM  (1 période de symboles dans quelques sous-porteuses)
    figure(4)
    colors = ['b','g','r','c','m','y'];
    for k=1:min(length(colors),(carrier_symb_count-1))
        plot(1:ifft_size, signal_tx(k+1,:))
        plot(1:ifft_size, signal_tx(k+1,:), colors(k))
        hold on
    end
    
    grid on
    axis ([0 ifft_size -limt limt])
    ylabel('Amplitude')
    xlabel('Temps')
    title('1 période de symboles dans quelques sous-porteuses')
    
end

% ------------------------------------- %
% ##### ajout du préfixe cyclique ##### %
% ------------------------------------- %
end_symb = size(signal_tx, 2); % fin d'un symbole sans le préfixe
signal_tx = [signal_tx(:,(end_symb-guard_time+1):end_symb) signal_tx];

% "parellel to serial"
signal_tx = signal_tx'; 
signal_tx = reshape(signal_tx, 1, size(signal_tx,1)*size(signal_tx,2));
