function [A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g)
% split_matrices_and_cov  矩阵分块与残差理论协方差计算（离线设计）
%   根据论文公式 (19) 将全局观测器矩阵按行/列分块为各计算中心的局域
%   矩阵；根据公式 (25)-(26) 计算全局与各区域残差的理论协方差。
%
%   公式 (19) — 局域矩阵拆分：
%       将全局 A_z 和 L 按各计算中心管辖的子系统索引拆分为局域矩阵。
%       对于中心 ω 管辖的子系统集合 I_ω：
%           A_z_omega{ω} = A_z(I_ω_rows, I_ω_rows)  — 局域状态矩阵
%           L_omega{ω}   = L(I_ω_rows, I_ω_ys)       — 局域观测器增益
%       其中 I_ω_rows 为中心 ω 的状态行索引集合，
%       I_ω_ys 为中心 ω 的传感器输出列索引集合。
%
%   公式 (25) — 稳态误差协方差（离散 Lyapunov 方程）：
%       Σ_Δ = Σ_w + L · Σ_v · L'
%       Σ_e = A_z · Σ_e · A_z' + Σ_Δ
%       求解 Σ_e = dlyap(A_z, Σ_Δ)
%
%   公式 (26) — 残差理论协方差：
%       Σ_{r_all} = C_g · Σ_e · C_g' + Σ_v     — 全局残差协方差
%       Σ_{r_ω}   = C_{g,ω} · Σ_e · C_{g,ω}' + Σ_{v,ω}
%                 — 各区域残差协方差（Σ_{r_all} 的对角分块）
%
%   Inputs:
%       A_z           - 全局残差发生器状态矩阵，N_x × N_x
%       L             - 全局观测器增益矩阵，N_x × N_y
%       indices_omega - 各计算中心管辖的子系统索引，cell array
%                       e.g. {[1, 3], [2, 4]} 表示中心 1 管子系统 1,3
%       Sigma_w       - 过程噪声协方差，cell array {Σ_{w,1},...,Σ_{w,n_s}}
%                       或数值矩阵 N_x × N_x
%       Sigma_v       - 测量噪声协方差，cell array {Σ_{v,1},...,Σ_{v,n_s}}
%                       （无传感器子系统为 []，自动过滤）或数值矩阵 N_y × N_y
%       C_g           - （可选）全局输出矩阵，N_y × N_x。
%                       若不提供，残差协方差以误差协方差替代。
%
%   Outputs:
%       A_z_omega    - 各区域的局域残差发生器矩阵，cell array {A_z_1, ..., A_z_Ω}
%       L_omega      - 各区域的局域观测器增益，cell array {L_1, ..., L_Ω}
%       Sigma_r_omega - 各区域残差理论协方差，cell array {Σ_{r,1}, ..., Σ_{r,Ω}}
%       Sigma_r_all   - 全局残差理论协方差，N_y × N_y（或 N_x × N_x 若无 C_g）
%
%   Example:
%       [A_z_om, L_om, Sr_om, Sr_all] = split_matrices_and_cov(...
%           A_z, L, {[1,3], [2,4]}, Sigma_w, Sigma_v, C_g);
%       for w = 1:n_omega
%           fprintf('Center %d: Σ_r = %.4e\n', w, Sr_om{w});
%       end

%% ========================================================================
%  1. 预处理：推断维度并构建全局噪声协方差矩阵
% ========================================================================

% --- 1a. 从 cell array 或数值矩阵中提取各子系统维度 ---
if iscell(Sigma_w)
    n_s  = length(Sigma_w);
    n_x  = zeros(1, n_s);
    for i = 1:n_s
        n_x(i) = size(Sigma_w{i}, 1);
    end
    Sigma_w_full = blkdiag(Sigma_w{:});
else
    Sigma_w_full = Sigma_w;
    N_x = size(Sigma_w_full, 1);
    n_s = 1;
    n_x = N_x;
end
N_x = sum(n_x);

if iscell(Sigma_v)
    has_output = ~cellfun(@isempty, Sigma_v);
    n_y = zeros(1, n_s);
    n_y(has_output) = cellfun(@(Sv) size(Sv, 1), Sigma_v(has_output));
    Sigma_v_nonempty = Sigma_v(has_output);
    if ~isempty(Sigma_v_nonempty)
        Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
    else
        Sigma_v_full = zeros(0);
    end
else
    Sigma_v_full = Sigma_v;
    n_y = size(Sigma_v_full, 1);
end
N_y = sum(n_y);

% --- 1b. 验证维度一致性 ---
assert(size(A_z, 1) == N_x && size(A_z, 2) == N_x, ...
    'A_z 维度 (%d×%d) 与 Sigma_w 推断的 N_x=%d 不一致。', ...
    size(A_z, 1), size(A_z, 2), N_x);
assert(size(L, 1) == N_x, ...
    'L 行数 %d 与 N_x=%d 不一致。', size(L, 1), N_x);
assert(size(L, 2) == N_y, ...
    'L 列数 %d 与 N_y=%d 不一致。', size(L, 2), N_y);

% --- 1c. 可选 C_g 参数 ---
if nargin < 6 || isempty(C_g)
    C_g = [];
    use_exact_Cg = false;
else
    use_exact_Cg = true;
    assert(size(C_g, 1) == N_y && size(C_g, 2) == N_x, ...
        'C_g 维度 (%d×%d) 与 N_y=%d, N_x=%d 不一致。', ...
        size(C_g, 1), size(C_g, 2), N_y, N_x);
end

%% ========================================================================
%  2. 构建子系统 → 全局索引的映射
% ========================================================================

% --- 状态索引映射：第 i 个子系统在全局状态向量中的行范围 ---
cum_n_x = [0, cumsum(n_x)];              % 累积状态偏移
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% --- 输出索引映射：第 i 个子系统在全局输出向量中的行范围 ---
cum_n_y = [0, cumsum(n_y)];              % 累积输出偏移
output_rows = cell(1, n_s);
for i = 1:n_s
    if n_y(i) > 0
        output_rows{i} = (cum_n_y(i) + 1) : cum_n_y(i + 1);
    else
        output_rows{i} = [];              % 无传感器子系统无对应行
    end
end

%% ========================================================================
%  3. 公式 (19)：矩阵拆分 — A_z_omega 和 L_omega
% ========================================================================

n_omega = length(indices_omega);

A_z_omega = cell(1, n_omega);
L_omega   = cell(1, n_omega);

for omega = 1:n_omega
    idx = indices_omega{omega};          % 中心 ω 管辖的子系统索引

    % --- 状态行/列索引（按管辖子系统收集）---
    rows_x = [];
    for s = idx
        rows_x = [rows_x, state_rows{s}];            %#ok<AGROW>
    end

    % --- 传感器输出列索引（仅收集有传感器的子系统）---
    cols_y = [];
    for s = idx
        if ~isempty(output_rows{s})
            cols_y = [cols_y, output_rows{s}];        %#ok<AGROW>
        end
    end

    % 局域状态矩阵：提取中心管辖子系统对应的行/列块
    A_z_omega{omega} = A_z(rows_x, rows_x);

    % 局域观测器增益：提取状态行 + 本地传感器列
    if ~isempty(cols_y)
        L_omega{omega} = L(rows_x, cols_y);
    else
        L_omega{omega} = [];              % 中心无传感器
    end
end

%% ========================================================================
%  4. 公式 (25)：稳态误差协方差 — 解离散 Lyapunov 方程
% ========================================================================

% Σ_Δ = Σ_w + L · Σ_v · L'（公式 25 的驱动噪声协方差，T=I 简化）
Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';

% 验证 Σ_Δ 的半正定性
assert(all(eig(Sigma_Delta) >= -1e-12), ...
    'Σ_Δ = Σ_w + L·Σ_v·L'' 必须为半正定矩阵。');

% 解离散 Lyapunov 方程：Σ_e = A_z · Σ_e · A_z' + Σ_Δ
try
    Sigma_e = dlyap(A_z, Sigma_Delta);
catch ME
    warning('[split_matrices_and_cov] dlyap 求解失败: %s', ME.message);
    % 回退：用有限和近似稳态协方差
    Sigma_e = Sigma_Delta;
    A_z_power = A_z;
    for p = 1:500
        Sigma_e = Sigma_e + A_z_power * Sigma_Delta * A_z_power';
        A_z_power = A_z_power * A_z;
        if norm(A_z_power, 'fro') < 1e-12
            break;
        end
    end
end

% 验证 Σ_e 的半正定性
if any(eig(Sigma_e) < -1e-10)
    warning('[split_matrices_and_cov] Σ_e 存在负特征值，可能数值不稳定。');
end

%% ========================================================================
%  5. 公式 (26)：残差理论协方差 — Σ_r_all 和 Σ_r_omega
% ========================================================================

if use_exact_Cg
    % --- 精确计算：Σ_r_all = C_g · Σ_e · C_g' + Σ_v ---
    Sigma_r_all = C_g * Sigma_e * C_g' + Sigma_v_full;

    % --- 提取各区域残差协方差 ---
    Sigma_r_omega = cell(1, n_omega);
    for omega = 1:n_omega
        idx = indices_omega{omega};

        % 收集中心 ω 管辖子系统对应的输出行索引
        rows_y = [];
        for s = idx
            if ~isempty(output_rows{s})
                rows_y = [rows_y, output_rows{s}];    %#ok<AGROW>
            end
        end

        if ~isempty(rows_y)
            % 局域残差协方差 = 对应输出块的子矩阵
            Sigma_r_omega{omega} = Sigma_r_all(rows_y, rows_y);
        else
            Sigma_r_omega{omega} = [];
        end
    end
else
    % --- 近似：以误差协方差 Σ_e 代替残差协方差 ---
    % （当 C_g 不可用时。注意：后续 T² 阈值需基于实际残差重新标定。）
    warning(['[split_matrices_and_cov] C_g 未提供，' ...
        '以误差协方差 Σ_e 近似残差协方差。后续 T² 阈值需基于实际残差校准。']);
    Sigma_r_all = Sigma_e;

    Sigma_r_omega = cell(1, n_omega);
    for omega = 1:n_omega
        idx = indices_omega{omega};

        % 收集中心 ω 管辖子系统的状态行索引
        rows_x = [];
        for s = idx
            rows_x = [rows_x, state_rows{s}];        %#ok<AGROW>
        end

        % 局域残差协方差 ≈ 对应状态块的子矩阵
        Sigma_r_omega{omega} = Sigma_r_all(rows_x, rows_x);
    end
end

%% ========================================================================
%  6. 输出维度汇总
% ========================================================================

fprintf('[split_matrices_and_cov] 拆分完成（%d 个计算中心）：\n', n_omega);
for omega = 1:n_omega
    fprintf('  中心 %d: A_z_omega = %d×%d, L_omega = %d×%d, Σ_r_ω = %d×%d\n', ...
        omega, ...
        size(A_z_omega{omega}, 1), size(A_z_omega{omega}, 2), ...
        size(L_omega{omega}, 1), size(L_omega{omega}, 2), ...
        size(Sigma_r_omega{omega}, 1), size(Sigma_r_omega{omega}, 2));
end

end
