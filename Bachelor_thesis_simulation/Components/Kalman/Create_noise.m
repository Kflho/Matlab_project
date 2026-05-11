function [Vk,Wk]=Create_noise()
% 生成过程噪声协方差矩阵 
sigma1_sq = 0.1^2;  % 第1维方差
sigma2_sq = 0.1^2;  % 第2维方差
sigma3_sq = 0.1^2; % 第3维方差
sigma4_sq = 0.1^2; % 第4维方差
%Wk可用Q表示
Wk = diag([sigma1_sq, sigma2_sq, sigma3_sq, sigma4_sq]);

% 生成观测噪声协方差矩阵

sigma5_sq=0.2^2; 
sigma6_sq=0.2^2; 
%Vk可用R表示
Vk = diag([sigma5_sq, sigma6_sq]);