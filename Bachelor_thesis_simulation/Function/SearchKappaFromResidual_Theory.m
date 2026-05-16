function [kappa_opt, epsilon_opt, kappa_range, Pf, Pd, Pm] = SearchKappaFromResidual_Theory(r2_ts, attack_start, attack_end, ...
                                                                      mu0_theo, sigma2_theo, cf, cm, lambda, kappa_range)
% 基于论文式(4-31)-(4-33)的最优 kappa 搜索（使用方差 sigma2）
% 输入：
%   r2_ts        : 残差能量 timeseries
%   attack_start, attack_end : 攻击时间段
%   mu0_theo      : 理论均值 = tr(Dq Va Dq')
%   sigma2_theo   : 理论方差 = 2*tr((Dq Va Dq')^2)
%   cf, cm        : 误报/漏报代价
%   lambda        : 正则化系数 (通常取0或小正数)
%   kappa_range   : 搜索向量 (默认 0:0.1:50)
% 输出：
%   kappa_opt, epsilon_opt, kappa_range, Pf, Pd, Pm

    if nargin < 9
        kappa_range = 0:0.1:50;        % 方差较小，可能需要较大 kappa，范围可调
    end

    t = r2_ts.Time(:);
    r2 = r2_ts.Data(:);
    is_attack = (t >= attack_start) & (t <= attack_end);
    r2_normal = r2(~is_attack);
    r2_attack = r2(is_attack);

    Pf = zeros(size(kappa_range));
    Pm = zeros(size(kappa_range));
    Loss = zeros(size(kappa_range));

    for i = 1:length(kappa_range)
        k = kappa_range(i);
        sigma0 = sqrt(sigma2_theo);         % 新加一行
        epsilon = mu0_theo + k * sigma0;    % 用标准差代替方差
        
        Pf(i) = mean(r2_normal > epsilon);
        Pm(i) = mean(r2_attack <= epsilon);
        Loss(i) = cf * Pf(i) + cm * Pm(i) + lambda * k;
    end

    [minLoss, idx] = min(Loss);
    kappa_opt = kappa_range(idx);
    sigma0 = sqrt(sigma2_theo);
    epsilon_opt = mu0_theo + kappa_opt * sigma0;
    Pd = 1 - Pm;

    fprintf('理论参数: μ0 = %.6f, σ² = %.6e\n', mu0_theo, sigma2_theo);
    fprintf('最优 κ = %.2f,  阈值 ε* = %.6f,  最小损失 = %.6f\n', kappa_opt, epsilon_opt, minLoss);
    fprintf('对应指标 → P_f = %.4f,  P_d = %.4f,  P_m = %.4f\n', Pf(idx), Pd(idx), Pm(idx));
end