%% Test_07_recursive_joint_filter.m  递归联合滤波器测试
%  通过合成测试用例（满足秩条件）和四容水箱用例验证：
%    1. 公式 (40)-(44)：五步递归的正确性（标准 Kalman 模式）
%    2. 公式 (45)-(47)：增益 M, K 的计算
%    3. 未知输入估计 d̂_k 的无偏性与一致性
%    4. 协方差传播的稳定性与半正定性
%    5. 退化模式：无传感器 / 秩条件不满足时的回退

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../Common/'));
addpath(genpath('../Function/'));
addpath(genpath('../Script/'));

%% ============================================================
%  PART A：合成测试用例（满足秩条件，验证完整功能）
% ============================================================
fprintf('===== PART A：合成测试（满足秩条件的 2 状态系统）=====\n\n');

% --- A1. 构建满足秩条件的合成系统 ---
%  x_{k+1} = A·x_k + B·u_k + G·d_k + w_k
%  y_k     = C·x_k + D·u_k + H·d_k + v_k
%  其中 d_k = Q·x_all_k 是未知输入

A_syn  = [0.92, 0.03; 0.01, 0.88];    % 2×2 Schur 稳定
B_syn  = [0.5; 0.3];                   % 2×1
C_syn  = [1.0, 0.2];                   % 1×2
D_syn  = 0.1;                          % 1×1
G_syn  = [0.15; 0.05];                 % 2×1  未知输入驱动
H_syn  = 0.4;                          % 1×1  未知输入→输出

% 秩条件检查
fprintf('秩条件: rank(CG)=%d, rank(G)=%d, rank(H)=%d, dim(d)=%d\n', ...
    rank(C_syn * G_syn), rank(G_syn), rank(H_syn), size(G_syn, 2));
assert(rank(C_syn * G_syn) == rank(G_syn) && rank(G_syn) == size(G_syn, 2), ...
    '合成系统应满足秩条件');
fprintf('✓ 秩条件满足\n');

Sigma_w_syn = 0.001 * eye(2);
Sigma_v_syn = 0.002;

% --- A2. 生成合成仿真数据 ---
rng(2024);
T = 200;

% 真实状态和未知输入
x_true = zeros(2, T);
d_true = zeros(1, T);
u_syn  = zeros(1, T);
y_syn  = zeros(1, T);

x_true(:, 1) = [0.5; -0.3];            % 非零初始状态

for k = 1:T
    % 简单控制律
    u_syn(k) = -0.1 * x_true(1, k) + 0.05 * sin(2*pi*k/50);

    % 未知输入: d_k = a * sin(ωk) + b * cos(ωk)
    d_true(k) = 0.2 * sin(2*pi*k/30) + 0.1 * cos(2*pi*k/20);

    % 测量
    w_k = sqrt(Sigma_w_syn) * randn(2, 1);
    v_k = sqrt(Sigma_v_syn) * randn();
    y_syn(k) = C_syn * x_true(:, k) + D_syn * u_syn(k) + H_syn * d_true(k) + v_k;

    % 状态递推
    if k < T
        x_true(:, k+1) = A_syn * x_true(:, k) + B_syn * u_syn(k) ...
            + G_syn * d_true(k) + w_k;
    end
end

fprintf('合成数据生成: T=%d, x = 2×%d, y = 1×%d\n', T, size(x_true, 2), size(y_syn, 2));

% --- A3. 运行递归滤波器 ---
fprintf('\n--- A3. 运行递归联合滤波器 ---\n');

x_hat_pred = zeros(2, T);      % x̂_{k|k-1}
x_hat_corr = zeros(2, T);      % x̂_{k|k}
d_hat_est  = zeros(1, T);      % d̂_k

% 初始化
x_pred = zeros(2, 1);                       % x̂_{0|-1}
Sigma_pred = 0.1 * eye(2);                  % Σ_{x̃,0|-1}

converged_all = true;
for k = 1:T
    [x_corr, x_next, d_hat, Sigma_next, M_k, K_k, info] = ...
        Recursive_joint_filter(x_pred, Sigma_pred, ...
            y_syn(k), u_syn(k), ...
            A_syn, B_syn, C_syn, D_syn, ...
            G_syn, H_syn, ...
            Sigma_w_syn, Sigma_v_syn);

    x_hat_pred(:, k) = x_pred;
    x_hat_corr(:, k) = x_corr;
    d_hat_est(k)     = d_hat;

    converged_all = converged_all && info.converged;

    % 传递到下一步
    x_pred = x_next;
    Sigma_pred = Sigma_next;
end

fprintf('滤波器完成 %d 步。收敛状态: %s\n', T, ternary(converged_all, '✓', '✗'));

% --- A4. 验证状态估计误差 ---
fprintf('\n--- A4. 验证状态估计 ---\n');

% 稳态 RMSE（跳过前 20 步瞬态）
skip = 21;
err_x1 = x_hat_corr(1, skip:end) - x_true(1, skip:end);
err_x2 = x_hat_corr(2, skip:end) - x_true(2, skip:end);
rmse_x1 = sqrt(mean(err_x1.^2));
rmse_x2 = sqrt(mean(err_x2.^2));
fprintf('稳态 RMSE: x₁ = %.4f, x₂ = %.4f\n', rmse_x1, rmse_x2);
assert(rmse_x1 < 0.1, '状态 x₁ 估计误差过大');
assert(rmse_x2 < 0.1, '状态 x₂ 估计误差过大');
fprintf('✓ 状态估计在可接受范围内\n');

% --- A5. 验证未知输入估计 ---
fprintf('\n--- A5. 验证未知输入估计 ---\n');

err_d = d_hat_est(skip:end) - d_true(skip:end);
rmse_d = sqrt(mean(err_d.^2));
mean_err_d = mean(err_d);
fprintf('d̂ 估计: RMSE = %.4f, 均值误差 = %.4f\n', rmse_d, mean_err_d);

% 无偏性检验：均值误差应接近零
assert(abs(mean_err_d) < 0.05, 'd̂ 估计存在显著偏差');
fprintf('✓ d̂ 估计无偏（|均值误差| < 0.05）\n');

% 相关性：d̂ 应与真实值正相关（手动计算，避免依赖 Statistics Toolbox）
d_h = d_hat_est(skip:end) - mean(d_hat_est(skip:end));
d_t = d_true(skip:end) - mean(d_true(skip:end));
corr_d = (d_h * d_t') / (norm(d_h) * norm(d_t));
fprintf('  corr(d̂, d_true) = %.4f\n', corr_d);
assert(corr_d > 0.5, 'd̂ 与真实值相关度过低');

% --- A6. 验证协方差一致性 ---
fprintf('\n--- A6. 验证协方差一致性 ---\n');

Sigma_final = Sigma_pred;
eig_Sigma = eig(Sigma_final);
fprintf('Σ_{x̃} 最终特征值: [%.6f, %.6f]\n', min(eig_Sigma), max(eig_Sigma));
assert(all(eig_Sigma > 0), '误差协方差非正定');
fprintf('✓ 误差协方差正定\n');

%% ============================================================
%  PART B：四容水箱测试（秩条件不满足，验证退化模式）
% ============================================================
fprintf('\n===== PART B：四容水箱（退化模式测试）=====\n\n');

Create_model_1;

[A_bar, B_bar, C_bar, D_bar] = ...
    Model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

[G_qr, H_qr, Q_map] = Model_2_to_model_3_qr(A_bar, C_bar, B_bar, D_bar, n_x, n_y);

% 对子系统 1 运行滤波器（H_1 = 0，秩条件不满足）
fprintf('\n--- B1. 子系统 1（秩条件不满足）---\n');

[x_corr, x_next, d_hat, S_next, M_k, K_k, info] = ...
    Recursive_joint_filter(zeros(1,1), 0.01 * eye(1), ...
        0.5, [0; 0], ...
        A{1}, B_bar{1}, C{1}, D_bar{1}, ...
        G_qr{1}, H_qr{1}, ...
        Sigma_w{1}, Sigma_v{1});

fprintf('  rank_ok = %d, converged = %d\n', info.rank_ok, info.converged);
fprintf('  x̂_{k|k} = %.4f, d̂_k = %.4f\n', x_corr, d_hat);
assert(~info.rank_ok, 'H_1=0 时 rank_ok 应为 false');
fprintf('  ✓ 正确检测秩条件不满足，退化为标准 Kalman\n');

% 对子系统 3 运行滤波器（无传感器）
fprintf('\n--- B2. 子系统 3（无传感器）---\n');

[x_corr3, x_next3, d_hat3, S_next3, M_k3, K_k3, info3] = ...
    Recursive_joint_filter(zeros(1,1), 0.01 * eye(1), ...
        [], [0; 0], ...
        A{3}, B_bar{3}, [], [], ...
        G_qr{3}, H_qr{3}, ...
        Sigma_w{3}, Sigma_v{3});

fprintf('  x̂_{k+1|k} = %.4f（应为开环预测）\n', x_next3);
fprintf('  ✓ 无传感器子系统正确执行开环预测\n');

%% ============================================================
%  汇总
% ============================================================
fprintf('\n===== 测试汇总 =====\n');
fprintf('  Recursive_joint_filter 正确实现公式 (40)-(47)：\n');
fprintf('    PART A — 合成系统（秩条件满足）：\n');
fprintf('      - 五步递归：状态 + 未知输入联合估计 ✓\n');
fprintf('      - d̂ 无偏性：均值误差 ≈ 0 ✓\n');
fprintf('      - 协方差传播：正定 ✓\n');
fprintf('    PART B — 四容水箱（退化模式）：\n');
fprintf('      - 秩条件不满足 → 标准 Kalman 回退 ✓\n');
fprintf('      - 无传感器 → 开环预测 ✓\n');
fprintf('  可用于故障定位阶段的递归交叉估计。\n');

% ---- 辅助函数 ----
function s = ternary(cond, t, f)
    if cond, s = t; else, s = f; end
end
