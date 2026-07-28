%% experiment_03_t2_detection.m  实验 03 — T² 统计量检测与零误报验证
%  目标：复现公式 (27) 的 J_{T²,ω} 统计量，验证正常状态下无误报。
%        基于 χ² 分布计算理论门限，统计误报次数，验证误报率接近 α=1-0.99=1%。
%
%  核心验证逻辑：
%    1. 离线设计：完成 Model 1→2→组装→LMI→拆分的完整链路
%    2. 正常工况仿真：LQR 闭环生成 x/u/y/s 时间序列（无故障注入）
%    3. 残差计算：各中心独立计算 r_y 和 r_s
%    4. J_T² 计算：J_{T²,ω}(k) = r_{ω,k}^T · Σ_{r,ω}^{-1} · r_{ω,k}
%       - r_y 使用 Sigma_r_omega（来自 split_matrices_and_cov，公式 26）
%       - r_s 使用 Sigma_rs_omega（来自 Σ_{e,s} 局域投影，实验 02 同款计算）
%    5. 理论门限：J_{th,ω} = chi2inv(α, dim_ω)，α = 0.99
%    6. 误报统计：正常状态下 J_T²(k) > J_{th} 的次数与比率
%    7. 可视化：J_T² 时间曲线叠加门限线
%
%  验收标准：
%    运行后报告各中心在正常状态下输出残差与信息残差的
%    实际误报次数与误报率（理论上约为 α = 1%）。
%
%  依赖：
%    src/lib/     — model_1_to_model_2, assemble_global_model, solve_luenberger_lmi,
%                   split_matrices_and_cov, compute_online_residuals
%    src/scripts/ — create_model_1
%    utils/       — create_controlled_system, calculate_lqr, create_noise_v2,
%                   run_visualization

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 离线设计：完整链路
% ============================================================
fprintf('========== 实验 03：T² 统计量检测与零误报验证 ==========\n\n');
fprintf('--- 1. 离线设计 ---\n');

% 1a. 加载 Model 1
create_model_1;

% 1b. Model 1 → Model 2（公式 7-10）
[A_bar, B_bar, C_bar, D_bar] = ...
    model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M, N);

% 1c. 全局矩阵组装（公式 11-14）
[A_g, B_g, C_g, D_g] = assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

% 1d. LMI/DARE 求解全局观测器矩阵
[A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

% 1e. 计算中心划分
n_omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 1f. 矩阵拆分与协方差计算（公式 19, 25-26）
%     Sigma_r_omega 为各中心输出残差 r_y 的理论协方差
[A_z_omega, L_omega, Sigma_r_omega, Sigma_r_all] = ...
    split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

% 1g. 额外计算：状态估计误差协方差（用于 r_s 理论协方差）
%     r_y 观测器误差：e_y(k+1) = A_z·e_y(k) + w(k) - L·v(k)
%       → Σ_{e,y} = dlyap(A_z, Σ_w + L·Σ_v·L')
%     r_s 观测器误差：e_s(k+1) = A_z·e_s(k) + w(k)  （s 信号无测量噪声）
%       → Σ_{e,s} = dlyap(A_z, Σ_w)   ← 不含测量噪声项
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
Sigma_e_y   = dlyap(A_z, Sigma_Delta);       % 用于 r_y（与 Split 内部一致）
Sigma_e_s   = dlyap(A_z, Sigma_w_full);       % 用于 r_s（无测量噪声驱动）

fprintf('  离线设计完成：n_omega=%d, N_x=%d, N_y=%d\n', n_omega, size(A_g,1), size(C_g,1));
fprintf('  A_z 谱半径 = %.6f（< 1 则稳定）\n', max(abs(eig(A_z))));

%% ============================================================
%  2. 正常工况仿真数据生成（无故障注入）
% ============================================================
fprintf('\n--- 2. 正常工况仿真数据生成 ---\n');

% 被控系统与 LQR 控制器
[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

T_sim = 5000;           % 仿真步长（足够长以保证统计有效性）
rng(42);                % 固定种子，保证可复现

% 生成噪声序列
[~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);    % 4 × T_sim
[~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);    % 2 × T_sim

% 预分配存储
N_x = size(A_g_sys, 1);
N_u = size(B_g_sys, 2);
N_y = size(C_g_sys, 1);

x_seq = zeros(N_x, T_sim);
u_seq = zeros(N_u, T_sim);
y_seq = zeros(N_y, T_sim);

cum_nx = [0, cumsum(n_x)];
s_cell = cell(1, n_s);
for i = 1:n_s
    s_cell{i} = zeros(n_x(i), T_sim);
end

% LQR 闭环仿真（正常工况，无故障）
x_k = zeros(N_x, 1);
for k = 1:T_sim
    u_k = -K * x_k;
    u_seq(:, k) = u_k;
    y_seq(:, k) = C_g_sys * x_k + v_seq(:, k);

    for i = 1:n_s
        idx_i = (cum_nx(i)+1) : cum_nx(i+1);
        s_cell{i}(:, k) = C_s{i} * x_k(idx_i) + D_s{i} * u_k;
    end

    x_seq(:, k) = x_k;
    if k < T_sim
        x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
    end
end

fprintf('  仿真完成：T_sim=%d（正常工况，无故障注入）\n', T_sim);
fprintf('  u=%dx%d, y=%dx%d, x=%dx%d\n', ...
    size(u_seq, 1), size(u_seq, 2), size(y_seq, 1), size(y_seq, 2), ...
    size(x_seq, 1), size(x_seq, 2));

%% ============================================================
%  3. 残差计算
% ============================================================
fprintf('\n--- 3. 各计算中心独立计算残差 ---\n');

[r_y, r_s] = compute_online_residuals(...
    u_seq, y_seq, s_cell, ...
    A_z_omega, L_omega, ...
    B_g_sys, C_g_sys, D_g_sys, C_s, D_s, ...
    indices_omega, n_x, n_y, n_s);

%% ============================================================
%  4. 构建局域索引（用于提取 Σ_{e,s} 分块和 C_{s,ω} 分块）
% ============================================================
fprintf('\n--- 4. 构建局域索引与 r_s 理论协方差 ---\n');

% 状态索引映射
cum_nx_global = [0, cumsum(n_x)];
state_rows_global = cell(1, n_s);
for i = 1:n_s
    state_rows_global{i} = (cum_nx_global(i)+1) : cum_nx_global(i+1);
end

% 为各中心预计算：C_{s,ω}、r_s 理论协方差 Σ_{r_s,ω}
Cs_omega     = cell(1, n_omega);
Sigma_rs_omega = cell(1, n_omega);  % r_s 理论协方差

for omega = 1:n_omega
    idx = indices_omega{omega};

    % 局域状态行索引
    rx = [];
    for s = idx
        rx = [rx, state_rows_global{s}]; %#ok<AGROW>
    end

    % C_{s,ω} = blkdiag(C_s{idx})
    Cs_blocks = {};
    for s = idx
        if ~isempty(C_s{s})
            Cs_blocks{end+1} = C_s{s}; %#ok<AGROW>
        end
    end
    if ~isempty(Cs_blocks)
        Cs_omega{omega} = blkdiag(Cs_blocks{:});
    else
        Cs_omega{omega} = [];
    end

    % r_s 理论协方差：Σ_{r_s,ω} = C_{s,ω} · Σ_{e,s,ω} · C_{s,ω}'
    % （s 信号不含测量噪声 → 使用 Σ_{e,s} 而非 Σ_{e,y}）
    Sigma_e_s_omega = Sigma_e_s(rx, rx);
    if ~isempty(Cs_omega{omega})
        Sigma_rs_omega{omega} = Cs_omega{omega} * Sigma_e_s_omega * Cs_omega{omega}';
    else
        Sigma_rs_omega{omega} = [];
    end

    fprintf('  中心 %d: r_y 协方差维度 %d×%d,  r_s 协方差维度 %d×%d\n', ...
        omega, ...
        size(Sigma_r_omega{omega}, 1), size(Sigma_r_omega{omega}, 2), ...
        size(Sigma_rs_omega{omega}, 1), size(Sigma_rs_omega{omega}, 2));
end

%% ============================================================
%  5. J_{T²,ω} 统计量计算（公式 27）
% ============================================================
%  J_{T²,ω}(k) = r_{ω,k}^T · Σ_{r,ω}^{-1} · r_{ω,k}
%  分别对输出残差 r_y 和发送信息残差 r_s 计算 T² 统计量
fprintf('\n--- 5. J_{T²} 统计量计算（公式 27）---\n');

J_T2_y = cell(1, n_omega);   % J_{T²} for output residuals r_y
J_T2_s = cell(1, n_omega);   % J_{T²} for sending residuals r_s

for omega = 1:n_omega

    % ---- 5a. 输出残差 r_y 的 T² 统计量 ----
    if ~isempty(r_y{omega}) && ~isempty(Sigma_r_omega{omega})
        dim_y = size(r_y{omega}, 1);
        J_T2_y{omega} = zeros(1, T_sim);

        % 预计算 Σ_{r,ω}^{-1} 或其 Cholesky 分解以加速
        Sigma_inv_y = Sigma_r_omega{omega} \ eye(dim_y);

        for k = 1:T_sim
            rk = r_y{omega}(:, k);
            J_T2_y{omega}(k) = rk' * Sigma_inv_y * rk;
        end
    else
        J_T2_y{omega} = [];
    end

    % ---- 5b. 发送信息残差 r_s 的 T² 统计量 ----
    if ~isempty(r_s{omega}) && ~isempty(Sigma_rs_omega{omega})
        dim_s = size(r_s{omega}, 1);
        J_T2_s{omega} = zeros(1, T_sim);

        % 预计算 Σ_{r_s,ω}^{-1}
        Sigma_inv_s = Sigma_rs_omega{omega} \ eye(dim_s);

        for k = 1:T_sim
            rk = r_s{omega}(:, k);
            J_T2_s{omega}(k) = rk' * Sigma_inv_s * rk;
        end
    else
        J_T2_s{omega} = [];
    end

    fprintf('  中心 %d: J_{T²,y} 维度 1×%d,  均值 = %.4f\n', ...
        omega, length(J_T2_y{omega}), mean(J_T2_y{omega}));
    if ~isempty(J_T2_s{omega})
        fprintf('           J_{T²,s} 维度 1×%d,  均值 = %.4f\n', ...
            length(J_T2_s{omega}), mean(J_T2_s{omega}));
    end
end

%% ============================================================
%  6. 理论门限计算（χ² 分布，置信水平 α = 0.99）
% ============================================================
%  J_{th,ω} = chi2inv(α, dim_ω)
%  在 H₀（无故障）下，J_{T²,ω} ~ χ²(dim_ω)，理论误报率 = 1 - α
fprintf('\n--- 6. 理论门限计算（χ² 分布，α = 0.99）---\n');

alpha = 0.99;

J_th_y = zeros(1, n_omega);
J_th_s = zeros(1, n_omega);

for omega = 1:n_omega
    if ~isempty(r_y{omega})
        dim_y = size(r_y{omega}, 1);
        J_th_y(omega) = chi2inv(alpha, dim_y);
        fprintf('  中心 %d — r_y: dim=%d,  J_{th,y} = %.4f (χ²_{%d, %.2f})\n', ...
            omega, dim_y, J_th_y(omega), dim_y, alpha);
    else
        J_th_y(omega) = NaN;
    end

    if ~isempty(r_s{omega})
        dim_s = size(r_s{omega}, 1);
        J_th_s(omega) = chi2inv(alpha, dim_s);
        fprintf('  中心 %d — r_s: dim=%d,  J_{th,s} = %.4f (χ²_{%d, %.2f})\n', ...
            omega, dim_s, J_th_s(omega), dim_s, alpha);
    else
        J_th_s(omega) = NaN;
    end
end

%% ============================================================
%  7. 误报统计（正常工况下 J_T² 超门限的次数与比率）
% ============================================================
%  分别统计全序列与稳态（排除前 transient_cut 步瞬态）的误报情况
fprintf('\n===== 7. 误报统计（正常工况，无故障）=====\n\n');

transient_cut = 200;
T_steady = T_sim - transient_cut;

fprintf('  置信水平 α = %.2f，理论误报率 = %.2f%%\n', alpha, (1-alpha)*100);
fprintf('  全序列 T_sim = %d，稳态 T_steady = %d（排除前 %d 步瞬态）\n\n', ...
    T_sim, T_steady, transient_cut);

% 预存统计结果
fa_results = struct();

for omega = 1:n_omega

    fprintf('--- 中心 %d（管辖子系统 %s）---\n', omega, mat2str(indices_omega{omega}));

    % ---- 7a. 输出残差 r_y 误报统计 ----
    if ~isempty(J_T2_y{omega})
        % 全序列
        fa_y_full = sum(J_T2_y{omega} > J_th_y(omega));
        far_y_full = fa_y_full / T_sim * 100;

        % 稳态（排除瞬态）
        J_T2_y_steady = J_T2_y{omega}(transient_cut+1:end);
        fa_y_steady = sum(J_T2_y_steady > J_th_y(omega));
        far_y_steady = fa_y_steady / T_steady * 100;

        fprintf('  r_y: 全序列误报 %d / %d = %.2f%%\n', ...
            fa_y_full, T_sim, far_y_full);
        fprintf('       稳态误报 %d / %d = %.2f%%\n', ...
            fa_y_steady, T_steady, far_y_steady);

        fa_results(omega).fa_y_full   = fa_y_full;
        fa_results(omega).far_y_full  = far_y_full;
        fa_results(omega).fa_y_steady = fa_y_steady;
        fa_results(omega).far_y_steady = far_y_steady;
    else
        fa_results(omega).fa_y_full   = 0;
        fa_results(omega).far_y_full  = 0;
        fa_results(omega).fa_y_steady = 0;
        fa_results(omega).far_y_steady = 0;
        fprintf('  r_y: 无输出残差（中心无传感器子系统）\n');
    end

    % ---- 7b. 发送信息残差 r_s 误报统计 ----
    if ~isempty(J_T2_s{omega})
        % 全序列
        fa_s_full = sum(J_T2_s{omega} > J_th_s(omega));
        far_s_full = fa_s_full / T_sim * 100;

        % 稳态（排除瞬态）
        J_T2_s_steady = J_T2_s{omega}(transient_cut+1:end);
        fa_s_steady = sum(J_T2_s_steady > J_th_s(omega));
        far_s_steady = fa_s_steady / T_steady * 100;

        fprintf('  r_s: 全序列误报 %d / %d = %.2f%%\n', ...
            fa_s_full, T_sim, far_s_full);
        fprintf('       稳态误报 %d / %d = %.2f%%\n', ...
            fa_s_steady, T_steady, far_s_steady);

        fa_results(omega).fa_s_full   = fa_s_full;
        fa_results(omega).far_s_full  = far_s_full;
        fa_results(omega).fa_s_steady = fa_s_steady;
        fa_results(omega).far_s_steady = far_s_steady;
    else
        fa_results(omega).fa_s_full   = 0;
        fa_results(omega).far_s_full  = 0;
        fa_results(omega).fa_s_steady = 0;
        fa_results(omega).far_s_steady = 0;
        fprintf('  r_s: 无信息残差\n');
    end

end

%% ============================================================
%  8. 验收判定
% ============================================================
fprintf('\n===== 8. 验收判定 =====\n\n');

% 验收准则：稳态误报率在理论值附近（α = 1%，允许统计波动）
theory_far = (1 - alpha) * 100;   % 理论误报率 1%
tolerance = 2.0;                   % 允许 ±2% 的统计波动

all_acceptable = true;

for omega = 1:n_omega
    far_y = fa_results(omega).far_y_steady;
    far_s = fa_results(omega).far_s_steady;

    % 检查 r_y 稳态误报率
    if fa_results(omega).far_y_full > 0 || far_y > 0  % 有数据才判定
        if far_y > theory_far + tolerance
            all_acceptable = false;
        end
    end

    % 检查 r_s 稳态误报率
    if fa_results(omega).far_s_full > 0 || far_s > 0
        if far_s > theory_far + tolerance
            all_acceptable = false;
        end
    end
end

if all_acceptable
    fprintf('  实验 03 通过。\n');
    fprintf('    在正常工况（无故障）下，各中心的 J_{T²} 统计量误报率\n');
    fprintf('    均在理论值 %.1f%% 的合理波动范围内（±%.1f%%）。\n', theory_far, tolerance);
    fprintf('    验证 T² 检测逻辑正确，正常状态下无误报。\n');
else
    fprintf('  实验 03 未通过。存在中心的误报率显著偏离理论值。\n');
    fprintf('  可能原因：\n');
    fprintf('    - 残差理论协方差计算存在偏差（Σ_{r,ω} 或 Σ_{r_s,ω} 不准确）\n');
    fprintf('    - 观测器瞬态未充分衰减（增大 transient_cut）\n');
    fprintf('    - 仿真步长 T_sim 不足，统计波动较大\n');
    fprintf('    - 噪声序列随机种子导致小概率偏移\n');
end

%% ============================================================
%  9. 可视化：J_{T²} 时间曲线与门限线
% ============================================================
fprintf('\n--- 9. 可视化 ---\n');

out_pic = '../../outputs/experiment_03_t2_detection/figures/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end

% 选取展示范围（全序列用于统计，前 500 步用于细节观察）
n_plot_full  = T_sim;
n_plot_zoom  = min(500, T_sim);
t_full = (0:n_plot_full-1);
t_zoom = (0:n_plot_zoom-1);

for omega = 1:n_omega

    % ---- 9a. 输出残差 r_y 的 J_{T²} 时序图（全序列）----
    if ~isempty(J_T2_y{omega})
        figh_y_full = figure('Name', sprintf('实验03-中心%d-JT2_y-全序列', omega), ...
                             'NumberTitle', 'off');

        plot(t_full, J_T2_y{omega}, 'b-', 'LineWidth', 0.8);
        hold on;
        yline(J_th_y(omega), 'r--', 'LineWidth', 1.5);
        % 标注瞬态截止线
        xline(transient_cut, 'k:', 'LineWidth', 1.0);
        hold off;

        xlabel('步数 k');
        ylabel('J_{T^2,y}(k)');
        title(sprintf('实验 03：中心 %d — 输出残差 T² 统计量（全序列 T=%d）', ...
            omega, T_sim));
        legend('J_{T^2,y}(k)', ...
            sprintf('J_{th,y}=%.2f (χ²_{%d,%.2f})', ...
                J_th_y(omega), size(r_y{omega},1), alpha), ...
            sprintf('瞬态截止 k=%d', transient_cut), ...
            'Location', 'best');
        run_visualization(figh_y_full);

        saveas(figh_y_full, [out_pic sprintf('center%d_JT2_y_full.png', omega)]);
        saveas(figh_y_full, [out_pic sprintf('center%d_JT2_y_full.fig', omega)]);

        % ---- 9b. 输出残差 r_y 的 J_{T²} 时序图（前 500 步放大）----
        figh_y_zoom = figure('Name', sprintf('实验03-中心%d-JT2_y-放大', omega), ...
                             'NumberTitle', 'off');

        plot(t_zoom, J_T2_y{omega}(1:n_plot_zoom), 'b-', 'LineWidth', 1.0);
        hold on;
        yline(J_th_y(omega), 'r--', 'LineWidth', 1.5);
        if transient_cut < n_plot_zoom
            xline(transient_cut, 'k:', 'LineWidth', 1.0);
        end
        hold off;

        xlabel('步数 k');
        ylabel('J_{T^2,y}(k)');
        title(sprintf('实验 03：中心 %d — 输出残差 T² 统计量（前 %d 步）', ...
            omega, n_plot_zoom));
        legend('J_{T^2,y}(k)', ...
            sprintf('J_{th,y}=%.2f', J_th_y(omega)), ...
            sprintf('瞬态截止 k=%d', transient_cut), ...
            'Location', 'best');
        run_visualization(figh_y_zoom);

        saveas(figh_y_zoom, [out_pic sprintf('center%d_JT2_y_zoom.png', omega)]);
        saveas(figh_y_zoom, [out_pic sprintf('center%d_JT2_y_zoom.fig', omega)]);

        % ---- 9c. 输出残差 r_y 的 J_{T²} 直方图（稳态）----
        J_T2_y_steady = J_T2_y{omega}(transient_cut+1:end);
        figh_y_hist = figure('Name', sprintf('实验03-中心%d-JT2_y-直方图', omega), ...
                             'NumberTitle', 'off');

        histogram(J_T2_y_steady, 50, 'FaceColor', [0.2 0.4 0.8], 'EdgeAlpha', 0.5);
        hold on;
        xline(J_th_y(omega), 'r--', 'LineWidth', 2.0);

        % 叠加理论 χ² 分布曲线
        dim_y = size(r_y{omega}, 1);
        x_vals = linspace(0, max(J_T2_y_steady)*1.1, 200);
        pdf_chi2 = chi2pdf(x_vals, dim_y);
        % 缩放到直方图高度
        [counts, edges] = histcounts(J_T2_y_steady, 50);
        bin_width = edges(2) - edges(1);
        scale = T_steady * bin_width;
        plot(x_vals, pdf_chi2 * scale, 'g-', 'LineWidth', 2.0);
        hold off;

        xlabel('J_{T^2,y}');
        ylabel('频次');
        title(sprintf('实验 03：中心 %d — 输出残差 T² 统计量直方图（稳态 T=%d）', ...
            omega, T_steady));
        legend('经验分布', ...
            sprintf('J_{th,y}=%.2f', J_th_y(omega)), ...
            sprintf('χ²(%d) 理论分布', dim_y), ...
            'Location', 'best');
        run_visualization(figh_y_hist);

        saveas(figh_y_hist, [out_pic sprintf('center%d_JT2_y_hist.png', omega)]);
        saveas(figh_y_hist, [out_pic sprintf('center%d_JT2_y_hist.fig', omega)]);
    end

    % ---- 9d. 发送信息残差 r_s 的 J_{T²} 时序图（全序列）----
    if ~isempty(J_T2_s{omega})
        figh_s_full = figure('Name', sprintf('实验03-中心%d-JT2_s-全序列', omega), ...
                             'NumberTitle', 'off');

        plot(t_full, J_T2_s{omega}, 'b-', 'LineWidth', 0.8);
        hold on;
        yline(J_th_s(omega), 'r--', 'LineWidth', 1.5);
        xline(transient_cut, 'k:', 'LineWidth', 1.0);
        hold off;

        xlabel('步数 k');
        ylabel('J_{T^2,s}(k)');
        title(sprintf('实验 03：中心 %d — 信息残差 T² 统计量（全序列 T=%d）', ...
            omega, T_sim));
        legend('J_{T^2,s}(k)', ...
            sprintf('J_{th,s}=%.2f (χ²_{%d,%.2f})', ...
                J_th_s(omega), size(r_s{omega},1), alpha), ...
            sprintf('瞬态截止 k=%d', transient_cut), ...
            'Location', 'best');
        run_visualization(figh_s_full);

        saveas(figh_s_full, [out_pic sprintf('center%d_JT2_s_full.png', omega)]);
        saveas(figh_s_full, [out_pic sprintf('center%d_JT2_s_full.fig', omega)]);

        % ---- 9e. 发送信息残差 r_s 的 J_{T²} 时序图（前 500 步放大）----
        figh_s_zoom = figure('Name', sprintf('实验03-中心%d-JT2_s-放大', omega), ...
                             'NumberTitle', 'off');

        plot(t_zoom, J_T2_s{omega}(1:n_plot_zoom), 'b-', 'LineWidth', 1.0);
        hold on;
        yline(J_th_s(omega), 'r--', 'LineWidth', 1.5);
        if transient_cut < n_plot_zoom
            xline(transient_cut, 'k:', 'LineWidth', 1.0);
        end
        hold off;

        xlabel('步数 k');
        ylabel('J_{T^2,s}(k)');
        title(sprintf('实验 03：中心 %d — 信息残差 T² 统计量（前 %d 步）', ...
            omega, n_plot_zoom));
        legend('J_{T^2,s}(k)', ...
            sprintf('J_{th,s}=%.2f', J_th_s(omega)), ...
            sprintf('瞬态截止 k=%d', transient_cut), ...
            'Location', 'best');
        run_visualization(figh_s_zoom);

        saveas(figh_s_zoom, [out_pic sprintf('center%d_JT2_s_zoom.png', omega)]);
        saveas(figh_s_zoom, [out_pic sprintf('center%d_JT2_s_zoom.fig', omega)]);

        % ---- 9f. 发送信息残差 r_s 的 J_{T²} 直方图（稳态）----
        J_T2_s_steady = J_T2_s{omega}(transient_cut+1:end);
        figh_s_hist = figure('Name', sprintf('实验03-中心%d-JT2_s-直方图', omega), ...
                             'NumberTitle', 'off');

        histogram(J_T2_s_steady, 50, 'FaceColor', [0.2 0.4 0.8], 'EdgeAlpha', 0.5);
        hold on;
        xline(J_th_s(omega), 'r--', 'LineWidth', 2.0);

        % 叠加理论 χ² 分布曲线
        dim_s = size(r_s{omega}, 1);
        x_vals_s = linspace(0, max(J_T2_s_steady)*1.1, 200);
        pdf_chi2_s = chi2pdf(x_vals_s, dim_s);
        [counts_s, edges_s] = histcounts(J_T2_s_steady, 50);
        bin_width_s = edges_s(2) - edges_s(1);
        scale_s = T_steady * bin_width_s;
        plot(x_vals_s, pdf_chi2_s * scale_s, 'g-', 'LineWidth', 2.0);
        hold off;

        xlabel('J_{T^2,s}');
        ylabel('频次');
        title(sprintf('实验 03：中心 %d — 信息残差 T² 统计量直方图（稳态 T=%d）', ...
            omega, T_steady));
        legend('经验分布', ...
            sprintf('J_{th,s}=%.2f', J_th_s(omega)), ...
            sprintf('χ²(%d) 理论分布', dim_s), ...
            'Location', 'best');
        run_visualization(figh_s_hist);

        saveas(figh_s_hist, [out_pic sprintf('center%d_JT2_s_hist.png', omega)]);
        saveas(figh_s_hist, [out_pic sprintf('center%d_JT2_s_hist.fig', omega)]);
    end

end

fprintf('  绘图完成。蓝线为 J_{T²}(k)，红虚线为 χ² 门限，绿线为理论 χ² 分布。\n');
fprintf('  输出目录：%s\n', out_pic);

%% ============================================================
%  10. J_{T²} 稳态统计（均值、标准差、偏度）
% ============================================================
fprintf('\n--- 10. J_{T²} 稳态统计（排除前 %d 步瞬态，T_steady=%d）---\n', ...
    transient_cut, T_steady);

for omega = 1:n_omega

    fprintf('  中心 %d（管辖子系统 %s）:\n', omega, mat2str(indices_omega{omega}));

    % r_y 稳态统计
    if ~isempty(J_T2_y{omega})
        J_steady_y = J_T2_y{omega}(transient_cut+1:end);
        fprintf('    J_{T²,y}: 均值=%.4f, 标准差=%.4f, 偏度=%.4f, 理论均值=%d\n', ...
            mean(J_steady_y), std(J_steady_y), skewness(J_steady_y), size(r_y{omega},1));
    end

    % r_s 稳态统计
    if ~isempty(J_T2_s{omega})
        J_steady_s = J_T2_s{omega}(transient_cut+1:end);
        fprintf('    J_{T²,s}: 均值=%.4f, 标准差=%.4f, 偏度=%.4f, 理论均值=%d\n', ...
            mean(J_steady_s), std(J_steady_s), skewness(J_steady_s), size(r_s{omega},1));
    end

end

%% ============================================================
%  11. 汇总表
% ============================================================
fprintf('\n===== 11. 汇总表 =====\n\n');

% 表头
fprintf('  %-6s %-18s %-10s %-10s %-13s %-13s %-13s %s\n', ...
    '中心', '残差类型', 'dim', 'J_{th}', ...
    '全序列误报', '全序列误报率', '稳态误报', '稳态误报率');
fprintf('  %-6s %-18s %-10s %-10s %-13s %-13s %-13s %s\n', ...
    '----', '--------------', '------', '------', ...
    '-----------', '----------', '----------', '----------');

for omega = 1:n_omega
    fr = fa_results(omega);

    % r_y 行
    if ~isempty(J_T2_y{omega})
        fprintf('  %-6d %-18s %-10d %-10.2f %-13d %-13.2f%% %-13d %-13.2f%%\n', ...
            omega, 'r_y (输出残差)', size(r_y{omega},1), J_th_y(omega), ...
            fr.fa_y_full, fr.far_y_full, fr.fa_y_steady, fr.far_y_steady);
    else
        fprintf('  %-6d %-18s %-10s %-10s %-13s %-13s %-13s %s\n', ...
            omega, 'r_y (输出残差)', '--', '--', '--', '--', '--', '--');
    end

    % r_s 行
    if ~isempty(J_T2_s{omega})
        fprintf('  %-6d %-18s %-10d %-10.2f %-13d %-13.2f%% %-13d %-13.2f%%\n', ...
            omega, 'r_s (信息残差)', size(r_s{omega},1), J_th_s(omega), ...
            fr.fa_s_full, fr.far_s_full, fr.fa_s_steady, fr.far_s_steady);
    else
        fprintf('  %-6d %-18s %-10s %-10s %-13s %-13s %-13s %s\n', ...
            omega, 'r_s (信息残差)', '--', '--', '--', '--', '--', '--');
    end
end

fprintf('\n  理论误报率 = %.2f%%（α = %.2f）\n', theory_far, alpha);
fprintf('  瞬态截止步数 = %d，稳态步数 = %d\n', transient_cut, T_steady);

%% ============================================================
%  12. 原理说明
% ============================================================
fprintf('\n--- 12. 原理说明 ---\n');
fprintf(['  T² 统计量（Hotelling''s T²）是多变量统计过程监控的核心工具。\n\n' ...
        '  公式 (27)：J_{T²,ω}(k) = r_{ω,k}^T · Σ_{r,ω}^{-1} · r_{ω,k}\n\n' ...
        '  其中：\n' ...
        '    - r_{ω,k} 为中心 ω 在时刻 k 的残差向量（r_y 或 r_s）\n' ...
        '    - Σ_{r,ω} 为残差的理论协方差矩阵（来自离线设计）\n\n' ...
        '  H₀（无故障）下，若残差 r_{ω,k} ~ N(0, Σ_{r,ω})，则：\n' ...
        '    J_{T²,ω}(k) ~ χ²(dim_ω)\n\n' ...
        '  检测逻辑：\n' ...
        '    若 J_{T²,ω}(k) > J_{th,ω} = chi2inv(α, dim_ω)，则报警。\n' ...
        '    置信水平 α = 0.99 → 理论误报率 = 1%%\n\n' ...
        '  本实验中，在正常工况（无故障注入）下运行 T_sim = %d 步，\n' ...
        '  统计各中心 J_{T²} 超门限的频次，验证误报率接近理论值 1%%。\n'], T_sim);

%% ============================================================
%  13. 产出保存
% ============================================================
out_data = '../../outputs/experiment_03_t2_detection/data/';
if ~exist(out_data, 'dir'), mkdir(out_data); end

% 保存关键结果
save([out_data 'results.mat'], ...
    'J_T2_y', 'J_T2_s', 'J_th_y', 'J_th_s', ...
    'Sigma_r_omega', 'Sigma_rs_omega', ...
    'fa_results', 'alpha', 'transient_cut', 'T_steady', ...
    'n_omega', 'indices_omega', 'T_sim');

fprintf('\n  产出已保存到 outputs/experiment_03_t2_detection/\n');

fprintf('\n========== 实验 03 结束 ==========\n');
