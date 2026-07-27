function [A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v)
% solve_luenberger_lmi  求解 Luenberger 观测器参数矩阵（离线设计）
%   根据论文 Theorem 1 中的 Luenberger 条件，求解全局残差发生器状态
%   矩阵 A_z 和观测器增益 L，并验证 A_z 的 Schur 稳定性。
%
%   Theorem 1 的 Luenberger 条件（取 T = I, G_z = I）：
%       A_z = A_g - L * C_g                        — 条件 1（状态耦合）
%       B_z = B_g - L * D_g                        — 条件 2（输入解耦）
%       C_z = C_g                                  — 条件 3（输出耦合）
%       D_z = D_g                                  — 条件 4（前馈解耦）
%
%   求解策略（两级回退）：
%       1. YALMIP LMI — 求解 Lyapunov 稳定性 LMI，得到保证 A_z Schur
%          稳定的 L（最严格的稳定性保证）
%       2. DARE Kalman — 基于离散代数 Riccati 方程，利用 Σ_w 和 Σ_v
%          得到最小方差意义下的最优 L（自动可检测则 Schur 稳定）
%
%   离散时间 Lyapunov 稳定性 LMI（Schur 补形式）：
%       Find  P = P' > 0,  Y
%       s.t.  [P,           A_g'*P - C_g'*Y' ] > 0
%             [P*A_g - Y*C_g,  P              ]
%   则  L = P \ Y,  A_z = A_g - L * C_g（由 LMI 保证 Schur 稳定）
%
%   DARE（Kalman 预测器形式）：
%       P = A_g*P*A_g' - A_g*P*C_g'*(C_g*P*C_g'+Σ_v)^{-1}*C_g*P*A_g' + Σ_w
%       L = A_g * P * C_g' * (C_g * P * C_g' + Σ_v)^{-1}
%       A_z = A_g - L * C_g（当 (A_g, C_g) 可检测时自动 Schur 稳定）
%
%   Inputs:
%       A_g      - 全局状态矩阵，维度 N_x × N_x（N_x = Σ n_{x,i}）
%       C_g      - 全局输出矩阵，维度 N_y × N_x（N_y = Σ n_{y,i}，已跳过无传感器子系统）
%       Sigma_w  - 过程噪声协方差，cell array {Σ_{w,1},...,Σ_{w,n_s}} 或 N_x×N_x 矩阵
%       Sigma_v  - 测量噪声协方差，cell array {Σ_{v,1},...,Σ_{v,n_s}} 或 N_y×N_y 矩阵
%                  （cell 中无传感器子系统对应 []，自动过滤）
%
%   Outputs:
%       A_z - 残差发生器状态矩阵，N_x × N_x（Schur 稳定）
%       L   - 观测器增益矩阵，N_x × N_y
%
%   Example:
%       [A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);
%       eig_Az = abs(eig(A_z));
%       assert(all(eig_Az < 1), 'A_z 不是 Schur 稳定的！');

%% ========================================================================
%  1. 维度验证与噪声协方差预处理
% ========================================================================

N_x = size(A_g, 1);
N_y = size(C_g, 1);

% --- 检查基本维度一致性 ---
assert(size(A_g, 2) == N_x, 'A_g 必须为方阵。');
assert(size(C_g, 2) == N_x, 'C_g 列数必须等于 A_g 维度。');
assert(size(A_g, 1) == N_x, 'A_g 行数必须等于 A_g 维度。');

% --- 将 cell array 形式的噪声协方差转为全局方阵 ---
if iscell(Sigma_w)
    Sigma_w_full = blkdiag(Sigma_w{:});
else
    Sigma_w_full = Sigma_w;
end
assert(isequal(size(Sigma_w_full), [N_x, N_x]), ...
    'Sigma_w 全局维度必须为 %d×%d，当前为 %d×%d。', N_x, N_x, ...
    size(Sigma_w_full, 1), size(Sigma_w_full, 2));

if iscell(Sigma_v)
    has_output = ~cellfun(@isempty, Sigma_v);
    Sigma_v_nonempty = Sigma_v(has_output);
    if ~isempty(Sigma_v_nonempty)
        Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
    else
        Sigma_v_full = zeros(0);
    end
else
    Sigma_v_full = Sigma_v;
end
assert(isequal(size(Sigma_v_full), [N_y, N_y]), ...
    'Sigma_v 全局维度必须为 %d×%d，当前为 %d×%d。', N_y, N_y, ...
    size(Sigma_v_full, 1), size(Sigma_v_full, 2));

% --- 验证正半定性 ---
assert(all(eig(Sigma_w_full) >= 0), 'Sigma_w 必须为半正定矩阵。');
assert(all(eig(Sigma_v_full) >= 0), 'Sigma_v 必须为半正定矩阵。');

%% ========================================================================
%  2. 策略 1：YALMIP LMI 求解（若可用）
% ========================================================================

yalmip_available = (exist('sdpvar', 'file') > 0);

if yalmip_available
    fprintf('[solve_luenberger_lmi] YALMIP 已检测到，使用 LMI 方法...\n');

    % --- 2a. 定义 LMI 决策变量 ---
    P = sdpvar(N_x, N_x, 'symmetric');
    Y = sdpvar(N_x, N_y, 'full');

    % --- 2b. 构建 Lyapunov 稳定性 LMI ---
    % 条件 P ≻ 0（正定）
    epsilon = 1e-8;
    LMI_P_posdef = (P >= epsilon * eye(N_x));

    % Schur 补 LMI：
    %   [P,           A_g'*P - C_g'*Y'] > 0
    %   [P*A_g - Y*C_g,  P             ]
    LMI_block11 = P;
    LMI_block12 = A_g' * P - C_g' * Y';
    LMI_block21 = P * A_g - Y * C_g;
    LMI_block22 = P;
    LMI_stability = ([LMI_block11, LMI_block12; ...
                      LMI_block21, LMI_block22] >= epsilon * eye(2 * N_x));

    % --- 2c. 求解可行性问题 ---
    constraints = [LMI_P_posdef, LMI_stability];
    diagnostics = optimize(constraints, []);

    if diagnostics.problem == 0
        % 提取解
        P_val = value(P);
        Y_val = value(Y);
        L = P_val \ Y_val;
        A_z = A_g - L * C_g;

        % 验证 Schur 稳定性
        eig_Az = abs(eig(A_z));
        if all(eig_Az < 1 - 1e-10)
            fprintf('[solve_luenberger_lmi] LMI 求解成功。');
            fprintf('  max|λ(A_z)| = %.6f < 1 ✓\n', max(eig_Az));
            return;
        else
            warning('[solve_luenberger_lmi] LMI 返回的解不满足严格 Schur 稳定性 ');
            fprintf('  (max|λ| = %.6f)，回退到 DARE 方法。\n', max(eig_Az));
        end
    else
        warning('[solve_luenberger_lmi] YALMIP 求解失败（问题码 %d），回退到 DARE 方法。', ...
            diagnostics.problem);
    end
else
    fprintf('[solve_luenberger_lmi] YALMIP 未安装，使用 DARE 方法。\n');
end

%% ========================================================================
%  3. 策略 2：DARE Kalman 滤波器设计（回退 / 优化）
% ========================================================================

% --- 3a. 求解离散代数 Riccati 方程（DARE）---
% 预测器形式 Kalman 滤波的先验误差协方差 P 满足：
%   P = A_g*P*A_g' - A_g*P*C_g'*(C_g*P*C_g'+Σ_v)^{-1}*C_g*P*A_g' + Σ_w
% 当 (A_g, C_g) 可检测且 Σ_w, Σ_v 正定时，DARE 有唯一半正定解。
try
    [P_dare, ~, G_dare] = dare(A_g', C_g', Sigma_w_full, Sigma_v_full);
catch
    error(['[solve_luenberger_lmi] DARE 求解失败。' ...
        '请确认 (A_g, C_g) 可检测且 Σ_w, Σ_v 正定。']);
end

% P_dare 满足：
%   A_g * P_dare * A_g' - P_dare
%       - A_g * P_dare * C_g' * (C_g * P_dare * C_g' + Σ_v)^{-1}
%         * C_g * P_dare * A_g' + Σ_w = 0

% --- 3b. 计算观测器增益 L（预测器形式）---
% Kalman 校正器增益：K = P * C_g' * (C_g * P * C_g' + Σ_v)^{-1}
% 预测器形式观测器增益：L = A_g * K
S = C_g * P_dare * C_g' + Sigma_v_full;          % 创新协方差
K = P_dare * C_g' / S;                            % 校正器 Kalman 增益（N_x × N_y）
L = A_g * K;                                      % 预测器观测器增益（N_x × N_y）

% --- 3c. 构造 A_z ---
A_z = A_g - L * C_g;

%% ========================================================================
%  4. 验证 Schur 稳定性
% ========================================================================

eig_Az = abs(eig(A_z));
fprintf('[solve_luenberger_lmi] DARE 求解完成。\n');
fprintf('  max|λ(A_z)| = %.6f\n', max(eig_Az));

if any(eig_Az >= 1)
    warning('[solve_luenberger_lmi] A_z 不是 Schur 稳定的！');
    fprintf('  不稳定特征值：');
    fprintf(' %.4f', eig_Az(eig_Az >= 1));
    fprintf('\n');
    fprintf('  所有特征值：');
    fprintf(' %.4f', eig_Az);
    fprintf('\n');
    fprintf('  请检查 (A_g, C_g) 是否可检测。\n');
else
    fprintf('  ✓ A_z 是 Schur 稳定的（所有 |λ| < 1）\n');
end

end
