clear all
close all
clc

filename_in = 'image.jpg';
filename_out = 'image.bin';

img = imread(filename_in);
buff = permute(img, [3 2 1]);
buff = buff(:);

padded = zeros(320*240*4,1);
padded(3:4:end) = buff(1:3:end); %R
padded(2:4:end) = buff(2:3:end); %G
padded(1:4:end) = buff(3:3:end); %B

lenna = fopen(filename_out, 'w');
fwrite(lenna, padded, 'uint8');
fclose(lenna);