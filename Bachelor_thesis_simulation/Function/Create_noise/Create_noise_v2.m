function [sim_Wk, sim_Vk, sim_Va, Vk, Wk] = Create_noise_v2(total_points)
% 生成三种独立的高斯白噪声序列，以及对应的协方差矩阵
% 输出：
%   sim_Wk : 过程噪声 timeseries  (4 × total_points)
%   sim_Vk : 观测噪声 timeseries  (2 × total_points)
%   sim_Va : 通信噪声 timeseries  (2 × total_points)
%   Vk     : 观测/通信噪声协方差矩阵 (2×2)
%   Wk     : 过程噪声协方差矩阵   (4×4)

    Ts = 1;

    % --- 过程噪声协方差 Wk ---
    Wk = diag([0.01538,0.01613,0.000324,0.000196]);

    % --- 观测/通信噪声协方差 Vk / Va ---
    % （两者统计特性相同，但序列独立）
    Va = diag([0.003844, 0.004032]);
    Vk = Va;   % 观测噪声协方差使用相同值

    % --- 时间向量 ---
    time = (0:total_points-1)' * Ts;

    % --- 生成过程噪声序列 (4维) ---
    noise_W = randn(total_points, 4);
    L_W = chol(Wk, 'lower');
    noise_W = (L_W * noise_W')';     % 变换为协方差 Wk
    sim_Wk = timeseries(noise_W', time);  % 注意转置，使数据为 4×N

    % --- 生成观测噪声序列 (2维)，独立 ---
    noise_V = randn(total_points, 2);
    L_V = chol(Vk, 'lower');
    noise_V = (L_V * noise_V')';
    sim_Vk = timeseries(noise_V', time);

    % --- 生成通信噪声序列 (2维)，独立 ---
    noise_A = randn(total_points, 2);
    L_A = chol(Va, 'lower');
    noise_A = (L_A * noise_A')';
    sim_Va = timeseries(noise_A', time);

end