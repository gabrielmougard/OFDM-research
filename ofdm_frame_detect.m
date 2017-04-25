% FONCTION : ofdm_frame_detect() 

% Cette fonction synchronise le signal reçu avant la démodulation  
% en détectant le début d'un train de signal reçu

function start_symb = ofdm_frame_detect(signal, symb_period, env, label)

% Trouve de manière approchée le début du train

signal = abs(signal);
% ===== diminution pour un départ approximé de la frame ===== %
idx = 1:env:length(signal);

samp_signal = signal(idx); 
mov_sum = filter(ones(1,round(symb_period/env)),1,samp_signal);
mov_sum = mov_sum(round(symb_period/env):length(mov_sum));
apprx = min(find(mov_sum==min(mov_sum))*env+symb_period);

% déplace l'indice en arrière par approximativement 110% dela période du
% symbole pour commencer la recherche
idx_start = round(apprx-1.1*symb_period);

% ===== vérification de la fenêtre diminuée ===== %
mov_sum = filter(ones(1,symb_period),1,signal(idx_start:round(apprx+symb_period/3)));
mov_sum = mov_sum(symb_period:length(mov_sum));
null_sig = find(mov_sum==min(mov_sum));
start_symb = min(idx_start + null_sig + symb_period) - 1;

% converti en index global
start_symb = start_symb + (label - 1);
