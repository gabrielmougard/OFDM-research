% ************* PARAMETERS INITIALIZATION ************* %
% This file configures parameters for the OFDM system.



file_in = [];

while isempty(file_in)
    file_in = input('nom du fichier source : ', 's');
    
    if exist([pwd '/' file_in],'file')~=2
        fprintf('"%s" existe pas dans le dossier actuel.\n', file_in);
        file_in = [];
    end
end

file_out = [file_in(1:length(file_in)-4) '_OFDM.bmp'];
disp(['Le fichier de sortie sera : ' file_out])

% Taille de l'IFFT (Doit être une puissance de deux)
ifft_size = 0.1; % pour rentrer dans la boucle ci-dessous
while (isempty(ifft_size) ||(rem(log2(ifft_size),1) ~= 0 || ifft_size < 8))
    ifft_size = input('Taille IFFT : ');
    
    if (isempty(ifft_size) ||(rem(log2(ifft_size),1) ~= 0 || ifft_size < 8))
        disp(' Taille de IFFT doit être au moins 8 ou une puissance de 2 .')
    end
end

% nombre de sous-porteuses
carrier_count = ifft_size; % pour entrer dans la boucle ci-dessous

while (isempty(carrier_count) ||(carrier_count>(ifft_size/2-2)) || carrier_count<2)
    
    carrier_count = input('Nombre de sous-porteuses: ');
    if (isempty(carrier_count) || (carrier_count > (ifft_size/2-2)))
        disp('Ne doit pas être plus grand que ("Taille IFFT"/2-2)')
    end
end

% bits par symbole (1 = BPSK, 2=QPSK, 4=16PSK, 8=256PSK)
symb_size = 0; % forcer l'entrée dans la boucle ci-dessous

while (isempty(symb_size) ||(symb_size~=1 && symb_size~=2 && symb_size~=4 && symb_size~=8))
    
    symb_size = input('Modulation(1=BPSK, 2=QPSK, 4=16PSK, 8=256PSK): ');
    
    if (isempty(symb_size) ||(symb_size~=1&&symb_size~=2&&symb_size~=4&&symb_size~=8))
        disp('Seulement 1, 2, 4, ou 8 peuvent être choisi')
    end
end


% Atténuation du milieux en dB

clipping = [];

while isempty(clipping)
    clipping = input('Amplitude du bruit par le milieu (en dB): ');
end

% SNR en dB

SNR_dB = [];

while isempty(SNR_dB)
    SNR_dB = input('(Signal-to-Noise Ratio) (SNR) en dB: ');
end

word_size = 8; % bits par mot de la source de données
guard_time = ifft_size/4; % longueur du préfixe cyclique pour chaque période de symbole
% 25% de la taille de l'IFFT

% nombre de symboles par sous-porteuses dans chaque "trains" pour la transmission
symb_per_frame = ceil(2^13/carrier_count);

% === Autres paramètres pouvant être utiles === %
% symb_period : longueur d'une période de symbole incluant le préfixe cyclique

symb_period = ifft_size + guard_time;
% head_len: longueur du header et du trailer de chaque donnée transmise

head_len = symb_period*8;
% envelope: symb_period/envelope est la taille du détecteur d'enveloppe
envelope = ceil(symb_period/256)+1;

% ===sous-porteuses associées aux mots binaires en entré de IFFT === %
% espacement pour les sous-porteuses allouées aux mots binaires en entrée de l'IFFT 

spacing = 0;

while (carrier_count*spacing) <= (ifft_size/2 - 2)
    spacing = spacing + 1;
end

spacing = spacing - 1;

% étalement des sous-porteuses en symboles binaires IFFT 

midFreq = ifft_size/4;
first_carrier = midFreq - round((carrier_count-1)*spacing/2);
last_carrier = midFreq + floor((carrier_count-1)*spacing/2);
carriers = [first_carrier:spacing:last_carrier] + 1;
conj_carriers = ifft_size - carriers + 2;
