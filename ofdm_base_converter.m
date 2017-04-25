%FONCTION : ofdm_base_convert()
%Cette fonction converti les données d'une base à une autre
%Par "base" je veux dire le nombre de bits que le symbole/mot utilise pour représenter les données

function data_out = ofdm_base_convert(data_in, base, new_base)

% Si la nouvelle base est plus grande que la base actuelle
% On transforme la taille des données de la base actuelle en un multiple de la taille de la nouvelle base

if new_base > base
    data_in = data_in(1:floor(length(data_in)/(new_base/base))*(new_base/base));
end

% base vers binaire
for k=1:base
    binary_matrix(k,:) = floor(data_in/2^(base-k));
    data_in = rem(data_in,2^(base-k));
end

% formate la matrice binaire aux dimensions de la nouvelle base
newbase_matrix = reshape(binary_matrix, new_base,size(binary_matrix,1)*size(binary_matrix,2)/new_base);

% binaire vers nouvelle base
data_out = zeros(1, size(newbase_matrix,2));

for k=1:new_base
    data_out = data_out + newbase_matrix(k,:)*(2^(new_base-k));
end
