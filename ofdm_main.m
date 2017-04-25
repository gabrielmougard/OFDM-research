%########################### INITIALISATION SYSTEME ####################

%commande permettant de ne pas faire de différence entre lettres minuscules
%et majuscules ( pour l'interface utilisateur )
warning('off','MATLAB:dispatcher:InexactMatch');

clear all; % détruit toute les données initiales dans le workspace MATLAB
close all; % ferme toute les fenêtres initialement ouvertes

fprintf('\n\n##########################################\n')
fprintf('#*********** Simulation OFDM ************#\n')
fprintf('##########################################\n\n')

% appel du script permettant de rentrer les paramètres utilisateurs
ofdm_parameters;
% sauvegarde des paramètres
save('ofdm_parameters');

% lit les données du fichier source à transmettre
x = imread(file_in);
% arrangement des données pour faciliter le traitement pour la modulation 

h = size(x,1);
w = size(x,2);
x = reshape(x', 1, w*h);
baseband_tx = double(x);

% conversion de la taille du mot original ( nb_bits par mots ) en taille du
% symbole ( nb_bits par symbole ). La taille du symbole est déterminée par
% le choix de la technique de modulation ( choisi par l'utilisateur lors de
% l'appel du script 'ofdm_parameters' )

baseband_tx = ofdm_base_convert(baseband_tx, word_size, symb_size);

% sauvegarde de la matrice de données initiale pour calculer les erreurs
% par la suite.
save('err_calc.mat', 'baseband_tx');

% ####################################################### %
% ******************* Transmetteur OFDM ****************** %
% ####################################################### %

tic; % démarre le chronomètre !!!

% generation d'un header et d'un trailer
f = 0.25;
header = sin(0:f*2*pi:f*2*pi*(head_len-1));
f=f/(pi*2/3);
header = header+sin(0:f*2*pi:f*2*pi*(head_len-1));

% converti les données brutes en "trains" de symboles

frame_guard = zeros(1, symb_period); % génération d'une matrice ligne de zéro de dimension de la longueur d'un train de symboles
time_wave_tx = [];
symb_per_carrier = ceil(length(baseband_tx)/carrier_count);
fig = 1;
if (symb_per_carrier > symb_per_frame) % === dans ce cas, affectation  cha === %
    power = 0;
    while ~isempty(baseband_tx) %tant que la baseband n'est pas vide
        
        % nombres de symbole par trains
        frame_len = min(symb_per_frame*carrier_count,length(baseband_tx));
        frame_data = baseband_tx(1:frame_len);
        
        % update
        baseband_tx = baseband_tx((frame_len+1):(length(baseband_tx)));
        % modulation OFDM
        
        time_signal_tx = ofdm_modulate(frame_data,ifft_size,carriers,conj_carriers, carrier_count, symb_size, guard_time, fig);
        fig = 0; %indique que la fonction ofdm_modulate() a déjà généré un tracé
        
        % ajoute un préfixe cyclique à chaque train de symboles modulés. 
        time_wave_tx = [time_wave_tx frame_guard time_signal_tx];
        frame_power = var(time_signal_tx);
        
    end
% étalonnage header 
power = power + frame_power;
% le signal OFDM modulé pour la transmission
time_wave_tx = [power*header time_wave_tx frame_guard power*header];


else % === une seule frame === %
    % modulation OFDM
    time_signal_tx = ofdm_modulate(baseband_tx,ifft_size,carriers,...
    conj_carriers, carrier_count, symb_size, guard_time, fig);
    % calcul la puissance du signal pour étalonner le header
    power = var(time_signal_tx);
    % le signal OFDM modulé pour la transmission
    time_wave_tx = [power*header frame_guard time_signal_tx frame_guard power*header];
end

% Resume ce qui s'est passé pendant la transmission...
peak = max(abs(time_wave_tx(head_len+1:length(time_wave_tx)-head_len)));
sig_rms = std(time_wave_tx(head_len+1:length(time_wave_tx)-head_len));
peak_rms_ratio = (20*log10(peak/sig_rms));

fprintf('\nRésumé de la transmission OFDM et modélisation du milieux de transmissio:\n')
fprintf('le rapport "Peak to RMS power" en entrée de milieux est : %f dB\n', peak_rms_ratio)

% ####################################################### %
% **************** MILIEUX DE PROPAGATION **************** %
% ####################################################### %

% ===== signal clipping ===== %
clipped_peak = (10^(0-(clipping/20)))*max(abs(time_wave_tx));
time_wave_tx(find(abs(time_wave_tx)>=clipped_peak)) = clipped_peak.*time_wave_tx(find(abs(time_wave_tx)>=clipped_peak))./abs(time_wave_tx(find(abs(time_wave_tx)>=clipped_peak)));

% ===== modélisation du bruit ambiant ===== %
power = var(time_wave_tx); % bruit blanc Gaussien (AWGN)
SNR_linear = 10^(SNR_dB/10);
noise_factor = sqrt(power/SNR_linear);
noise = randn(1,length(time_wave_tx)) * noise_factor;
time_wave_rx = time_wave_tx + noise;

% résumé de la modélisation du milieux de transmission de l'OFDM
peak = max(abs(time_wave_rx(head_len+1:length(time_wave_rx)-head_len)));
sig_rms = std(time_wave_rx(head_len+1:length(time_wave_rx)-head_len));
peak_rms_ratio = (20*log10(peak/sig_rms));
fprintf('Peak to RMS power ratio at exit of channel is: %f dB\n',peak_rms_ratio)

% Sauvegarde le signal pour qu'il soit reçu
save('received.mat', 'time_wave_rx', 'h', 'w');
fprintf('#******** les données OFDM ont été transmisent en %f secondes ********#\n\n', toc) % toc : fin du chronomètre !


% ####################################################### %
% ********************* RECEPTEUR OFDM ******************* %
% ####################################################### %

disp('Appuyer sur une touche pour commencer la réception des données...') 
pause;
clear all; % efface toutes les données stockées en mémoire 
tic; % démarre le chronomètre !

% appel du script ofdm_parameters.m pour paramétrer la réception
load('ofdm_parameters');

% données reçues
load('received.mat');
time_wave_rx = time_wave_rx.';
end_x = length(time_wave_rx);
start_x = 1;
data = [];
phase = [];
last_frame = 0;
unpad = 0;

if rem(w*h, carrier_count)~=0
    unpad = carrier_count - rem(w*h, carrier_count);
end

num_frame=ceil((h*w)*(word_size/symb_size)/(symb_per_frame*carrier_count));
fig = 0;

for k = 1:num_frame
    if k==1 || k==num_frame || rem(k,max(floor(num_frame/10),1))==0
        fprintf('Demodulation des frames #%d\n',k)
    end
    
% choisi une troncature appropriée du signal temporel pour détecter les données dans les frames 
	if k==1
        time_wave = time_wave_rx(start_x:min(end_x,(head_len+symb_period*((symb_per_frame+1)/2+1))));
    else
        time_wave = time_wave_rx(start_x:min(end_x, ...
        ((start_x-1) + (symb_period*((symb_per_frame+1)/2+1)))));
    end
    
% détecte les "data frame" qui contiennent seulement les infos utiles 
frame_start = ofdm_frame_detect(time_wave, symb_period, envelope, start_x);

    if k==num_frame
        last_frame = 1;
        frame_end = min(end_x, (frame_start-1) + symb_period*(1+ceil(rem(w*h,carrier_count*symb_per_frame)/carrier_count)));
    else
        frame_end=min(frame_start-1+(symb_per_frame+1)*symb_period, end_x);
    end
    
% prend le signal temporel pour la démodulation 
time_wave = time_wave_rx(frame_start:frame_end);


start_x = frame_end - symb_period;

    if k==ceil(num_frame/2)
        fig = 1;
    end
% demodulation du signal temporel reçu 
[data_rx, phase_rx] = ofdm_demod(time_wave, ifft_size, carriers, conj_carriers,guard_time, symb_size, word_size, last_frame, unpad, fig);

    if fig==1
        fig = 0; % indique que ofdm_demod() a déjà tracé un graphe
    end
    
phase = [phase phase_rx];
data = [data data_rx];

end

phase_rx = phase; % phase décodée
data_rx = data; % données reçues

% conversion taille symbole (bits/symbole) vers taille d'un mot fichier (bits/byte)

data_out = ofdm_base_convert(data_rx, symb_size, word_size);

fprintf('#********** données OFDM reçues en %f secondes *********#\n\n', toc) % toc : fin de chronomètre !

% ####################################################### %
% ************* AFFICHAGE DE LA RECEPTION *************** %
% ####################################################### %

% 'rogne' les données pour obtenir une image de dimension w*h

if length(data_out)>(w*h) % on enlève des données superflues
    data_out = data_out(1:(w*h));
elseif length(data_out)<(w*h) % sinon on remplace des rangées manquantes 
    buff_h = h;
    h = ceil(length(data_out)/w);
    
    % Si une ou plusieurs rangées de pixels manquent, envoyer un message
    % pour indiquer :

    if h~=buff_h
        disp('ATTENTION: image de sortie plus petite que image originale')
        disp(' Celà est due aux pertes dans la transmission.')
    end
    
    % pour que ce remplacement ne soit pas trop visible, le pixels manquant sera de la même couleur que celui du dessus 
    if length(data_out)~=(w*h)
        for k=1:(w*h-length(data_out))
            mend(k)=data_out(length(data_out)-w+k);
        end
        data_out = [data_out mend];
    end
end


% formate les données démodulées pour reconstruire une image bitmap

data_out = reshape(data_out, w, h)';
data_out = uint8(data_out);

% sauvegarde l'image de sortie en fichier bitmap (*.bmp)

imwrite(data_out, file_out, 'bmp');


% ####################################################### %
% ****************** CALCUL DES ERREURS ***************** %
% ####################################################### %


% récupère les données originales ( avant modulation ) pour le calcul des
% erreurs

load('err_calc.mat');
fprintf('\n#**************** Résumé des erreurs ****************#\n')

% calcul du taux de perte dans les données 
if length(data_rx)>length(baseband_tx)
    data_rx = data_rx(1:length(baseband_tx));
    phase_rx = phase_rx(1:length(baseband_tx));
    
elseif length(data_rx)<length(baseband_tx)
    fprintf('Taux de perte dans cette communication = %f%% (%d sur %d)\n', ...
    (length(baseband_tx)-length(data_rx))/length(baseband_tx)*100, ...
    length(baseband_tx)-length(data_rx), length(baseband_tx))

end

% trouve les erreurs
errors = find(baseband_tx(1:length(data_rx))~=data_rx);
fprintf('Total number of errors = %d (out of %d)\n',length(errors), length(data_rx))

% 'Bit Error Rate' ( nombre de bits erronés )
fprintf('Bit Error Rate (BER) = %f%%\n',length(errors)/length(data_rx)*100)

% find phase error in degrees and translate to -180 to +180 interval
% trouve les erreurs de phase en degrés et 
phase_tx = baseband_tx*360/(2^symb_size);
phase_err = (phase_rx - phase_tx(1:length(phase_rx)));
phase_err(find(phase_err>=180)) = phase_err(find(phase_err>=180))-360;
phase_err(find(phase_err<=-180)) = phase_err(find(phase_err<=-180))+360;
fprintf('Erreur moyenne de phase = %f (degrés)\n', mean(abs(phase_err)))

% Erreurs par pixels
x = ofdm_base_convert(baseband_tx, symb_size, word_size);
x = uint8(x);
x = x(1:(size(data_out,1)*size(data_out,2)));
y = reshape(data_out', 1, length(x));
err_pix = find(y~=x);
fprintf('Pourcentage d erreur des pixels de l image reçue = %f%%\n\n', ...
length(err_pix)/length(x)*100)

fprintf('##########################################\n')
fprintf('#****** FIN de la Simulation OFDM *******#\n')
fprintf('##########################################\n\n')
