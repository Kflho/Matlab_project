function [Sigma, sim_noise] = Create_noise_v2(total_points, sigma_diag)
% 创建一条高斯白噪声的协方差矩阵与 timeseries 序列
% 输入：
%   total_points : 仿真步数
%   sigma_diag   : 协方差对角线向量，同时决定噪声维度
%                   例：[0.0001, 0.0001, 0.0001, 0.0001] → 4维过程噪声
%                   例：[0.003844, 0.004032]             → 2维观测噪声
% 输出：
%   Sigma     : 噪声协方差矩阵 (n×n)，n = length(sigma_diag)
%   sim_noise : 噪声 timeseries (n × total_points)

    Ts = 1;

    % --- 协方差矩阵 ---
    Sigma = diag(sigma_diag);

    % --- 时间向量 ---
    time = (0:total_points-1)' * Ts;

    % --- 生成噪声序列 ---
    noise_dim = length(sigma_diag);
    noise = randn(total_points, noise_dim);
    L = chol(Sigma, 'lower');
    noise = (L * noise')';
    sim_noise = timeseries(noise', time);

end
