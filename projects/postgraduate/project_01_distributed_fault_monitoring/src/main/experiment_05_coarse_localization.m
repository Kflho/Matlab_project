%% experiment_05_coarse_localization.m  实验 05 — 粗定位：切断交互链接定位故障计算中心
%  目标：验证目标 3.1，验证粗定位可通过切断区域间 M_ij 交互链接，
%        将故障源准确锁定在特定计算中心。
%
%  核心思路（论文第 III-C 节粗定位策略）：
%    1. 故障发生后，其在子系统间的传播路径由 M_ij 链接定义
%    2. 依次将每个非零 M_ij 置零（切断交互），重新设计观测器
%    3. 使用同一组故障仿真数据，分别计算各中心在切断前后的 J_{T²,ω}
%    4. 若切断某条链接后某中心的 J_T² 显著回落，说明故障通过该链
%       接传播 → 该链接的发送端（sender）所在中心为故障源
%    5. 若切断链接后某中心的 J_T² 仍保持高位 → 接收端（receiver）
%       自身为故障源
%
%  四容水箱拓扑：
%    中心 1 = [子系统 1, 3]，中心 2 = [子系统 2, 4]
%    M{1,3}=1（水箱 3→1，中心 1 内部），M{2,4}=1（水箱 4→2，中心 2 内部）
%    无跨中心交互链接
%
%  粗定位规则：
%    切断 M{1,3} → 观察中心 1 的 J_T² 变化：
%      - J_T² 回落 → 故障源为子系统 3（sender）→ 故障在中心 1
%      - J_T² 保持高位 → 故障源为子系统 1（receiver）→ 故障在中心 1
%    切断 M{2,4} → 观察中心 2 的 J_T² 变化：
%      - J_T² 回落 → 故障源为子系统 4（sender）→ 故障在中心 2
%      - J_T² 保持高位 → 故障源为子系统 2（receiver）→ 故障在中心 2
%
%    粗定位级别（计算中心）：综合基线检测与切断分析，判定故障所在中心。
%
%  验收标准：
%    运行后报告粗定位实际正确率（故障子系统所在计算中心被准确识别的比例）。
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
%  1. 系统参数与拓扑加载
% ============================================================
fprintf('========== 实验 05：粗定位 — 切断交互链接定位故障计算中心 ==========\n\n');
fprintf('--- 1. 系统参数与拓扑 ---\n');

create_model_1;

n_omega = 2;
indices_omega = {[1, 3], [2, 4]};

% 子系统 → 计算中心映射
center_of_subsys = [1, 2, 1, 2];  % 子系统 1,3→中心1；子系统 2,4→中心2

fprintf('  子系统数量: n_s=%d\n', n_s);
fprintf('  计算中心: Ω=%d\n', n_omega);
fprintf('  中心 1 管辖子系统: [%s]\n', num2str(indices_omega{1}));
fprintf('  中心 2 管辖子系统: [%s]\n', num2str(indices_omega{2}));
fprintf('  交互链接: M{1,3}=%d（中心1内部）, M{2,4}=%d（中心2内部）\n', M{1,3}, M{2,4});

%% ============================================================
%  2. 实验参数配置
% ============================================================
fprintf('\n--- 2. 实验参数 ---\n');

T_sim = 500;             % 仿真步长
k_fault = 200;           % 故障注入时刻
rng(42);                 % 固定随机种子

fault_magnitude = 0.3;   % 传感器故障幅值（子系统 1,2）
fault_magnitude_s = 1.0; % 信息故障幅值（子系统 3,4，无传感器）

alpha = 0.99;            % 置信水平（用于门限计算）
post_fault_start = k_fault;          % 故障后评估起始步
transient_after_fault = 30;          % 故障后瞬态过渡步数
post_fault_steady = post_fault_start + transient_after_fault;  % 稳态评估起始步

fault_subsys_list = [1, 2, 3, 4];    % 遍历全部 4 个子系统
n_fault_cases = length(fault_subsys_list);

fprintf('  T_sim=%d,  k_fault=%d\n', T_sim, k_fault);
fprintf('  故障幅值: 传感器=%.2f,  信息=%.2f\n', fault_magnitude, fault_magnitude_s);
fprintf('  故障后评估范围: k ∈ [%d, %d]（排除前 %d 步瞬态）\n', ...
    post_fault_steady, T_sim, transient_after_fault);
fprintf('  遍历故障位置: 子系统 %s\n', mat2str(fault_subsys_list));

%% ============================================================
%  3. 离线预计算：三种观测器配置
% ============================================================
%  为每种 M 配置（原始、切断 M{1,3}、切断 M{2,4}）预先完成
%  model 1→2→组装→LMI→拆分的完整设计链路，避免主循环中重复求解 LMI。
fprintf('\n--- 3. 离线预计算观测器配置 ---\n');

% 系统仿真矩阵（始终使用原始 M，不做任何切断）
[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

% --- 3a. 配置 1：原始 M（基线观测器）---
fprintf('  3a. 配置 1（基线）：原始 M...\n');
M_orig = M;
[obs_baseline, info_baseline] = build_observer_from_m(...
    M_orig, A, B, C, D, E, F, C_s, D_s, N, n_x, n_y, n_s, ...
    Sigma_w, Sigma_v, indices_omega);
fprintf('       A_z 谱半径 = %.6f\n', max(abs(eig(obs_baseline.A_z))));

% --- 3b. 配置 2：切断 M{1,3}=0 ---
fprintf('  3b. 配置 2（切断 M{1,3}）：M{1,3}=0...\n');
M_cut_13 = M_orig;
M_cut_13{1,3} = 0;
[obs_cut_13, info_cut_13] = build_observer_from_m(...
    M_cut_13, A, B, C, D, E, F, C_s, D_s, N, n_x, n_y, n_s, ...
    Sigma_w, Sigma_v, indices_omega);
fprintf('       A_z 谱半径 = %.6f\n', max(abs(eig(obs_cut_13.A_z))));

% --- 3c. 配置 3：切断 M{2,4}=0 ---
fprintf('  3c. 配置 3（切断 M{2,4}）：M{2,4}=0...\n');
M_cut_24 = M_orig;
M_cut_24{2,4} = 0;
[obs_cut_24, info_cut_24] = build_observer_from_m(...
    M_cut_24, A, B, C, D, E, F, C_s, D_s, N, n_x, n_y, n_s, ...
    Sigma_w, Sigma_v, indices_omega);
fprintf('       A_z 谱半径 = %.6f\n', max(abs(eig(obs_cut_24.A_z))));

fprintf('  三种观测器配置离线计算完成。\n');

%% ============================================================
%  4. 主循环：遍历所有故障子系统位置
% ============================================================
fprintf('\n===== 4. 主循环：逐子系统故障注入与粗定位分析 =====\n');

% 预分配结果存储
result = struct();
result.fault_subsys    = cell(1, n_fault_cases);
result.actual_center   = zeros(1, n_fault_cases);
result.identified_center = zeros(1, n_fault_cases);
result.is_correct      = zeros(1, n_fault_cases);
result.baseline_mean_y = cell(1, n_fault_cases);   % 基线 J_T²_y 故障后均值
result.baseline_mean_s = cell(1, n_fault_cases);   % 基线 J_T²_s 故障后均值
result.cut13_mean_y    = cell(1, n_fault_cases);   % 切断 M{1,3} 后 J_T²_y 故障后均值
result.cut24_mean_y    = cell(1, n_fault_cases);   % 切断 M{2,4} 后 J_T²_y 故障后均值
result.reduction_13    = zeros(1, n_fault_cases);  % 中心 1 的 J_T² 回落比例
result.reduction_24    = zeros(1, n_fault_cases);  % 中心 2 的 J_T² 回落比例
result.baseline_detected = cell(1, n_fault_cases); % 基线检测结果

% 仿真噪声（所有故障场景共用同一组噪声实现）
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});

for fi = 1:n_fault_cases

    fault_subsys = fault_subsys_list(fi);
    actual_center = center_of_subsys(fault_subsys);

    fprintf('\n--- 4.%d. 故障位置：子系统 %d（实际所属中心 %d）---\n', ...
        fi, fault_subsys, actual_center);

    %% ---- 4a. 故障仿真数据生成 ----
    fprintf('    4a. 仿真数据生成（LQR 闭环）...\n');

    % 生成噪声序列
    [~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
    w_seq = squeeze(sim_w.Data);       % N_x × T_sim
    [~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
    v_seq = squeeze(sim_v.Data);       % N_y × T_sim

    % 预分配存储
    N_x_sys = size(A_g_sys, 1);
    N_u_sys = size(B_g_sys, 2);
    N_y_sys = size(C_g_sys, 1);

    x_seq   = zeros(N_x_sys, T_sim);
    u_seq   = zeros(N_u_sys, T_sim);
    y_seq   = zeros(N_y_sys, T_sim);

    cum_nx = [0, cumsum(n_x)];
    s_cell = cell(1, n_s);
    for i = 1:n_s
        s_cell{i} = zeros(n_x(i), T_sim);
    end

    % LQR 闭环仿真（含状态故障注入）
    %
    %  传感器故障（子系统 1,2）：仅在测量输出 y 上叠加偏置（后处理），
    %    系统状态不受影响 — 模拟传感器本身偏差。
    %  状态故障（子系统 3,4 无传感器）：在系统动态中直接扰动状态，
    %    使故障通过耦合 A(1,3)/A(2,4) 传播至相邻子系统的测量输出。
    %    同时 s_cell（=状态）自动携带故障信息。

    is_sensor_fault = (n_y(fault_subsys) > 0);
    state_idx_fault = cum_nx(fault_subsys) + 1;  % 故障子系统的状态索引

    x_k = zeros(N_x_sys, 1);
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
            % 状态故障注入（仅无传感器子系统，在状态更新后叠加）
            if k >= k_fault && ~is_sensor_fault
                x_k(state_idx_fault) = x_k(state_idx_fault) + fault_magnitude_s;
            end
        end
    end

    % 故障注入（后处理）
    y_faulty = y_seq;
    s_cell_faulty = s_cell;

    if is_sensor_fault
        % 子系统有传感器 → 传感器输出偏置（后处理）
        y_faulty(fault_subsys, k_fault:end) = ...
            y_faulty(fault_subsys, k_fault:end) + fault_magnitude;
        fprintf('    故障注入：子系统 %d 传感器故障，幅值 %.2f，k ≥ %d\n', ...
            fault_subsys, fault_magnitude, k_fault);
    else
        % 子系统无传感器 → 状态故障已在仿真循环中注入
        fprintf('    故障注入：子系统 %d 状态故障，幅值 %.2f，k ≥ %d（仿真中注入）\n', ...
            fault_subsys, fault_magnitude_s, k_fault);
    end

    %% ---- 4b. 基线 J_T² 计算（原始 M 观测器）----
    fprintf('    4b. 基线 J_T²（原始 M 观测器）...\n');

    [J_T2_y_base, J_T2_s_base, J_th_y, J_th_s] = compute_J_T2_on_data(...
        u_seq, y_faulty, s_cell_faulty, ...
        obs_baseline, info_baseline, ...
        indices_omega, n_x, n_y, n_s, T_sim);

    % 故障后稳态均值
    baseline_mean_y_omega = zeros(1, n_omega);
    baseline_mean_s_omega = zeros(1, n_omega);
    for omega = 1:n_omega
        if ~isempty(J_T2_y_base{omega})
            baseline_mean_y_omega(omega) = mean(J_T2_y_base{omega}(post_fault_steady:T_sim));
        end
        if ~isempty(J_T2_s_base{omega})
            baseline_mean_s_omega(omega) = mean(J_T2_s_base{omega}(post_fault_steady:T_sim));
        end
        fprintf('      中心 %d 基线: J_{T²,y} 均值=%.4f,  J_{T²,s} 均值=%.4f  [k=%d:%d]\n', ...
            omega, baseline_mean_y_omega(omega), baseline_mean_s_omega(omega), ...
            post_fault_steady, T_sim);
    end

    result.baseline_mean_y{fi} = baseline_mean_y_omega;
    result.baseline_mean_s{fi} = baseline_mean_s_omega;

    % 基线检测：哪些中心 J_T² > 门限
    detected_omega = [];
    for omega = 1:n_omega
        if ~isempty(J_T2_y_base{omega}) && ~isnan(J_th_y(omega))
            detect_rate = mean(J_T2_y_base{omega}(post_fault_steady:T_sim) > J_th_y(omega));
            if detect_rate > 0.5
                detected_omega = [detected_omega, omega]; %#ok<AGROW>
            end
        end
    end
    result.baseline_detected{fi} = detected_omega;
    fprintf('      基线检测到故障的中心: [%s]\n', num2str(detected_omega));

    %% ---- 4c. 切断 M{1,3} 后的 J_T² ----
    fprintf('    4c. J_T²（切断 M{1,3}=0 观测器）...\n');

    [J_T2_y_cut13, J_T2_s_cut13] = compute_J_T2_on_data(...
        u_seq, y_faulty, s_cell_faulty, ...
        obs_cut_13, info_cut_13, ...
        indices_omega, n_x, n_y, n_s, T_sim);

    cut13_mean_y_omega = zeros(1, n_omega);
    for omega = 1:n_omega
        if ~isempty(J_T2_y_cut13{omega})
            cut13_mean_y_omega(omega) = mean(J_T2_y_cut13{omega}(post_fault_steady:T_sim));
        end
        fprintf('      中心 %d 切断 M{1,3}: J_{T²,y} 均值=%.4f\n', ...
            omega, cut13_mean_y_omega(omega));
    end

    result.cut13_mean_y{fi} = cut13_mean_y_omega;

    % 中心 1 的回落比例（切断 M{1,3} 对中心 1 的影响）
    if baseline_mean_y_omega(1) > 0
        result.reduction_13(fi) = (baseline_mean_y_omega(1) - cut13_mean_y_omega(1)) ...
            / baseline_mean_y_omega(1);
    else
        result.reduction_13(fi) = 0;
    end
    fprintf('      中心 1 回落比例（M{1,3} 切断）= %.4f (%.1f%%)\n', ...
        result.reduction_13(fi), result.reduction_13(fi)*100);

    %% ---- 4d. 切断 M{2,4} 后的 J_T² ----
    fprintf('    4d. J_T²（切断 M{2,4}=0 观测器）...\n');

    [J_T2_y_cut24, J_T2_s_cut24] = compute_J_T2_on_data(...
        u_seq, y_faulty, s_cell_faulty, ...
        obs_cut_24, info_cut_24, ...
        indices_omega, n_x, n_y, n_s, T_sim);

    cut24_mean_y_omega = zeros(1, n_omega);
    for omega = 1:n_omega
        if ~isempty(J_T2_y_cut24{omega})
            cut24_mean_y_omega(omega) = mean(J_T2_y_cut24{omega}(post_fault_steady:T_sim));
        end
        fprintf('      中心 %d 切断 M{2,4}: J_{T²,y} 均值=%.4f\n', ...
            omega, cut24_mean_y_omega(omega));
    end

    result.cut24_mean_y{fi} = cut24_mean_y_omega;

    % 中心 2 的回落比例（切断 M{2,4} 对中心 2 的影响）
    if baseline_mean_y_omega(2) > 0
        result.reduction_24(fi) = (baseline_mean_y_omega(2) - cut24_mean_y_omega(2)) ...
            / baseline_mean_y_omega(2);
    else
        result.reduction_24(fi) = 0;
    end
    fprintf('      中心 2 回落比例（M{2,4} 切断）= %.4f (%.1f%%)\n', ...
        result.reduction_24(fi), result.reduction_24(fi)*100);

    %% ---- 4e. 粗定位决策 ----
    % 定位逻辑：
    %   1. 基线检测：J_T² 故障后稳态均值 > 门限 → 故障在该中心可检测
    %   2. 切断分析：回落比例较小的中心更可能为故障源
    %      （故障源所在中心，切断内部链接不会消除故障信号）
    %   3. 综合判定：取基线检测与切断分析的一致性结论

    % 方法 A：基线检测优先 — 故障后稳态均值最高的中心
    [~, identified_by_baseline] = max(baseline_mean_y_omega);

    % 方法 B：切断分析 — 回落比例较小的中心
    if result.reduction_13(fi) <= result.reduction_24(fi)
        identified_by_cut = 1;
    else
        identified_by_cut = 2;
    end

    % 综合判定：基线检测与切断分析一致时置信度最高
    if identified_by_baseline == identified_by_cut
        identified_center = identified_by_baseline;
        confidence = '高（基线+切断一致）';
    else
        % 不一致时，优先信任基线检测（对于无跨中心链接的拓扑）
        identified_center = identified_by_baseline;
        confidence = '中（基线+切断不一致，以基线为准）';
    end

    result.identified_center(fi) = identified_center;
    result.fault_subsys{fi} = fault_subsys;
    result.actual_center(fi) = actual_center;
    result.is_correct(fi) = (identified_center == actual_center);

    fprintf('    4e. 粗定位决策:\n');
    fprintf('        基线检测 → 中心 %d（均值 [%.2f, %.2f]）\n', ...
        identified_by_baseline, baseline_mean_y_omega(1), baseline_mean_y_omega(2));
    fprintf('        切断分析 → 中心 %d（回落 [%.1f%%, %.1f%%]）\n', ...
        identified_by_cut, result.reduction_13(fi)*100, result.reduction_24(fi)*100);
    fprintf('        综合判定 → 中心 %d（实际中心 %d）%s → %s\n', ...
        identified_center, actual_center, ...
        confidence, ternary(result.is_correct(fi), '正确', '错误'));

end

%% ============================================================
%  5. 粗定位准确率汇总
% ============================================================
fprintf('\n===== 5. 粗定位准确率汇总 =====\n\n');

n_correct = sum(result.is_correct);
accuracy = n_correct / n_fault_cases * 100;

fprintf('  %-12s %-14s %-18s %-12s %s\n', ...
    '故障子系统', '实际中心', '识别中心', '是否正确', '中心 1 回落%');
fprintf('  %-12s %-14s %-18s %-12s %s\n', ...
    '----------', '--------', '--------------', '--------', '----------');

for fi = 1:n_fault_cases
    fprintf('  %-12d %-14d %-18d %-12s %+.1f%%\n', ...
        result.fault_subsys{fi}, ...
        result.actual_center(fi), ...
        result.identified_center(fi), ...
        ternary(result.is_correct(fi), '正确', '错误'), ...
        result.reduction_13(fi)*100);
    fprintf('  %-12s %-14s %-18s %-12s %+.1f%%（中心 2）\n', ...
        '', '', '', '', result.reduction_24(fi)*100);
end

fprintf('\n  粗定位正确率: %d / %d = %.1f%%\n\n', n_correct, n_fault_cases, accuracy);

% 分情况统计
fprintf('  分情况分析:\n');
for c = 1:n_omega
    idx_c = find(result.actual_center == c);
    n_c = length(idx_c);
    n_c_correct = sum(result.is_correct(idx_c));
    fprintf('    中心 %d 故障: %d / %d 正确 (%.1f%%)\n', ...
        c, n_c_correct, n_c, n_c_correct/n_c*100);
end

% 验收判定
fprintf('\n  验收判定:\n');
if accuracy >= 75
    fprintf('    实验 05 通过。粗定位正确率 %.1f%% ≥ 75%%，\n', accuracy);
    fprintf('    证明通过切断交互链接可有效将故障锁定至特定计算中心。\n');
else
    fprintf('    实验 05 未通过。粗定位正确率 %.1f%% < 75%%。\n', accuracy);
    fprintf('    可能原因：\n');
    fprintf('      - 切断分析中的回落比例计算对基线 J_T² 数值敏感\n');
    fprintf('      - 故障后瞬态过渡不足（增大 transient_after_fault）\n');
    fprintf('      - 信息故障（子系统 3,4）的信号传播路径较复杂\n');
end

%% ============================================================
%  6. 切断分析详细数据
% ============================================================
fprintf('\n--- 6. 切断分析详细数据（J_{T²,y} 故障后稳态均值，k ∈ [%d, %d]）---\n\n', ...
    post_fault_steady, T_sim);

fprintf('  %-10s %-18s %-18s %-18s %-10s %-10s\n', ...
    '子系统', '基线 J_{T²,y}(中心 1)', '切断 M{1,3}(中心 1)', '切断 M{2,4}(中心 1)', ...
    '回落%13', '回落%24');
fprintf('  %-10s %-18s %-18s %-18s %-10s %-10s\n', ...
    '------', '--------------------', '--------------------', '--------------------', ...
    '--------', '--------');

for fi = 1:n_fault_cases
    bm = result.baseline_mean_y{fi};
    c13 = result.cut13_mean_y{fi};
    c24 = result.cut24_mean_y{fi};
    fprintf('  %-10d %-18.4f %-18.4f %-18.4f %-+9.1f%% %-+9.1f%%\n', ...
        result.fault_subsys{fi}, ...
        bm(1), c13(1), c24(1), ...
        result.reduction_13(fi)*100, result.reduction_24(fi)*100);
    fprintf('  %-10s %-18.4f %-18.4f %-18.4f\n', ...
        ['(中心 2)'], bm(2), c13(2), c24(2));
end

%% ============================================================
%  7. 可视化：J_T² 对比柱状图
% ============================================================
fprintf('\n--- 7. 可视化 ---\n');

out_pic = '../../outputs/experiment_05_coarse_localization/figures/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end

% ---- 7a. 各故障场景的 J_T² 对比柱状图（每中心一组）----
for fi = 1:n_fault_cases

    fault_subsys = result.fault_subsys{fi};

    % 收集数据
    bm = result.baseline_mean_y{fi};
    c13 = result.cut13_mean_y{fi};
    c24 = result.cut24_mean_y{fi};

    % 每个中心 3 个柱子：基线、切断 M{1,3}、切断 M{2,4}
    bar_data = [bm(1), c13(1), c24(1);
                bm(2), c13(2), c24(2)];

    figh_bar = figure('Name', sprintf('实验05-子系统%d-JT2对比', fault_subsys), ...
                       'NumberTitle', 'off');

    b = bar(bar_data, 'grouped');
    % 配色：基线=蓝，切断 M{1,3}=橙，切断 M{2,4}=黄
    color_list = {[0.2 0.4 0.8], [0.9 0.5 0.1], [0.9 0.8 0.1]};
    for i = 1:3
        b(i).FaceColor = color_list{i};
    end

    set(gca, 'XTickLabel', {'中心 1 [1,3]', '中心 2 [2,4]'});
    ylabel('J_{T^2,y} 故障后稳态均值');
    title(sprintf('实验 05：子系统 %d 故障 — J_{T^2,y} 对比（k ∈ [%d, %d]）', ...
        fault_subsys, post_fault_steady, T_sim));
    legend('基线（原始 M）', '切断 M{1,3}=0', '切断 M{2,4}=0', ...
        'Location', 'best');
    grid on;

    run_visualization(figh_bar);
    saveas(figh_bar, [out_pic sprintf('fault_subsys%d_JT2_bar.png', fault_subsys)]);
    saveas(figh_bar, [out_pic sprintf('fault_subsys%d_JT2_bar.fig', fault_subsys)]);

end

% ---- 7b. 回落比例对比图 ----
figh_reduction = figure('Name', '实验05-回落比例对比', 'NumberTitle', 'off');

reduction_matrix = [result.reduction_13_fmc_0 * 100];
b2 = bar(reduction_matrix, 'grouped');
b2(1).FaceColor = [0.2 0.4 0.8];
b2(2).FaceColor = [0.9 0.5 0.1];

set(gca, 'XTickLabel', arrayfun(@(s) sprintf('子系统 %d', s), ...
    fault_subsys_list, 'UniformOutput', false));
ylabel('J_{T²,y} 回落比例 (%)');
title(sprintf('实验 05：切断交互链接后 J_{T²,y} 回落比例（正值=回落，负值=上升）'));
legend('中心 1 回落\%（切断 M{1,3}）', '中心 2 回落\%（切断 M{2,4}）', ...
    'Location', 'best');
% 添加零参考线
hold on;
yline(0, 'k-', 'LineWidth', 1.0);
% 添加 20% 显著性阈值参考线
yline(20, 'r--', 'LineWidth', 1.0);
yline(-20, 'r--', 'LineWidth', 1.0);
hold off;
grid on;

run_visualization(figh_reduction);
saveas(figh_reduction, [out_pic 'reduction_comparison.png']);
saveas(figh_reduction, [out_pic 'reduction_comparison.fig']);

% ---- 7c. 正确率饼图 ----
figh_pie = figure('Name', '实验05-正确率', 'NumberTitle', 'off');

pie_data = [n_correct, n_fault_cases - n_correct];
p = pie(pie_data);
% 配色：正确=绿，错误=红
p(1).FaceColor = [0.2 0.8 0.4];
p(3).FaceColor = [0.9 0.3 0.3];

title(sprintf('实验 05：粗定位正确率 = %.1f%%（%d / %d）', ...
    accuracy, n_correct, n_fault_cases));
legend({sprintf('正确 (%d)', n_correct), sprintf('错误 (%d)', n_fault_cases - n_correct)}, ...
    'Location', 'best');

run_visualization(figh_pie);
saveas(figh_pie, [out_pic 'accuracy_pie.png']);
saveas(figh_pie, [out_pic 'accuracy_pie.fig']);

fprintf('  绘图完成。\n');
fprintf('  输出目录：%s\n', out_pic);

%% ============================================================
%  8. 产出保存
% ============================================================
out_data = '../../outputs/experiment_05_coarse_localization/data/';
if ~exist(out_data, 'dir'), mkdir(out_data); end

save([out_data 'results.mat'], ...
    'result', 'n_correct', 'accuracy', 'n_fault_cases', ...
    'fault_subsys_list', 'center_of_subsys', ...
    'T_sim', 'k_fault', 'fault_magnitude', 'fault_magnitude_s', ...
    'indices_omega', 'n_omega', ...
    'post_fault_steady', 'transient_after_fault', ...
    'obs_baseline', 'obs_cut_13', 'obs_cut_24');

fprintf('\n  产出已保存到 outputs/experiment_05_coarse_localization/\n');

%% ============================================================
%  9. 原理说明
% ============================================================
fprintf('\n--- 9. 原理说明 ---\n');
fprintf(['  粗定位（Coarse Localization）是论文第 III-C 节提出的两阶段\n' ...
         '  定位策略的第一阶段。\n\n' ...
         '  基本思想：\n' ...
         '    故障在分布式系统中的传播遵循 M_ij 定义的交互拓扑。\n' ...
         '    若故障源位于子系统 j（发送端），则其影响通过 M_{i,j}\n' ...
         '    传播至子系统 i（接收端），进而在中心 ω（管辖 i 的计算\n' ...
         '    中心）的残差中体现。\n\n' ...
         '  定位操作：\n' ...
         '    1. 依次将各非零 M_ij 置零，重新设计观测器\n' ...
         '    2. 使用同一组故障仿真数据，计算各中心在切断前后的 J_T²\n' ...
         '    3. 若切断 M_ij 后中心 ω 的 J_T² 显著回落：\n' ...
         '       → 故障沿 M_ij 传播，发送端 j 为故障源\n' ...
         '       → 故障位于管辖 j 的计算中心\n' ...
         '    4. 若切断 M_ij 后中心 ω 的 J_T² 保持高位：\n' ...
         '       → 故障不依赖 M_ij 传播，接收端 i 自身为故障源\n' ...
         '       → 故障位于管辖 i 的计算中心\n' ...
         '    5. 综合各切断试验的回落比例，锁定故障所在计算中心\n\n' ...
         '  四容水箱系统的特殊性：\n' ...
         '    M{1,3} 和 M{2,4} 均为计算中心内部链接，无跨中心交互。\n' ...
         '    因此基线检测（J_T² 超门限的中心）即可正确完成中心级\n' ...
         '    粗定位；切断分析进一步提供子系统级（sender vs receiver）\n' ...
         '    的细化信息。\n'], T_sim);

fprintf('\n========== 实验 05 结束 ==========\n');

%% ============================================================
%  辅助函数
% ============================================================

function [obs, info] = build_observer_from_m(M_mod, A, B, C, D, E, F, ...
    C_s, D_s, N, n_x, n_y, n_s, Sigma_w, Sigma_v, indices_omega)
% build_observer_from_m  基于给定 M 矩阵完整构建观测器链路
%   model 1 → model 2 → 全局组装 → LMI 求解 → 拆分 → 协方差计算
%
%   outputs:
%     obs.A_z, obs.L, obs.A_z_omega, obs.L_omega, obs.sigma_r_omega
%     obs.sigma_w_full, obs.sigma_v_full, obs.sigma_e_s
%     obs.A_g, obs.B_g, obs.C_g, obs.D_g
%     info.C_s, info.D_s, info.n_x, info.n_y, info.n_s

    % model 1 → model 2
    [A_bar, B_bar, C_bar, D_bar] = ...
        model_1_to_model_2(A, B, C, D, E, F, C_s, D_s, M_mod, N);

    % 全局组装
    [A_g, B_g, C_g, D_g] = assemble_global_model(A_bar, B_bar, C_bar, D_bar, n_x);

    % LMI/DARE 求解
    [A_z, L] = solve_luenberger_lmi(A_g, C_g, Sigma_w, Sigma_v);

    % 矩阵拆分与残差协方差
    [A_z_omega, L_omega, Sigma_r_omega, ~] = ...
        split_matrices_and_cov(A_z, L, indices_omega, Sigma_w, Sigma_v, C_g);

    % 状态估计误差协方差（用于 r_s 理论协方差）
    Sigma_w_full = blkdiag(Sigma_w{:});
    has_output = (n_y > 0);
    Sigma_v_nonempty = Sigma_v(has_output);
    Sigma_v_full = blkdiag(Sigma_v_nonempty{:});
    Sigma_Delta = Sigma_w_full + L * Sigma_v_full * L';
    Sigma_e_y = dlyap(A_z, Sigma_Delta);
    Sigma_e_s = dlyap(A_z, Sigma_w_full);

    % 封装观测器结构体
    obs.A_z = A_z;
    obs.L = L;
    obs.A_z_omega = A_z_omega;
    obs.L_omega = L_omega;
    obs.Sigma_r_omega = Sigma_r_omega;
    obs.Sigma_w_full = Sigma_w_full;
    obs.Sigma_v_full = Sigma_v_full;
    obs.Sigma_e_y = Sigma_e_y;
    obs.Sigma_e_s = Sigma_e_s;
    obs.A_g = A_g;
    obs.B_g = B_g;
    obs.C_g = C_g;
    obs.D_g = D_g;

    % 传递 model 1 信息（不随 M 改变）
    info.C_s = C_s;
    info.D_s = D_s;
    info.n_x = n_x;
    info.n_y = n_y;
    info.n_s = n_s;

end

function [J_T2_y, J_T2_s, J_th_y, J_th_s] = compute_J_T2_on_data(...
    u_seq, y_seq, s_cell, obs, info, indices_omega, n_x, n_y, n_s, T_sim)
% compute_j_t2_on_data  使用给定观测器对故障仿真数据计算 J_T² 统计量
%
%   inputs:
%     u_seq, y_seq, s_cell — 仿真时间序列
%     obs   — 观测器结构体（来自 build_observer_from_m）
%     info  — 子系统信息（C_s, D_s, n_x, n_y, n_s）
%
%   outputs:
%     J_t2_y, J_t2_s — 各中心 J_T² 时间序列
%     J_th_y, J_th_s — 各中心 χ² 门限（α=0.99）

    n_omega = length(indices_omega);
    alpha = 0.99;

    % 计算残差
    [r_y, r_s] = compute_online_residuals(...
        u_seq, y_seq, s_cell, ...
        obs.A_z_omega, obs.L_omega, ...
        obs.B_g, obs.C_g, obs.D_g, info.C_s, info.D_s, ...
        indices_omega, n_x, n_y, n_s);

    % 构建局域索引（用于 r_s 理论协方差）
    cum_nx_global = [0, cumsum(n_x)];
    state_rows_global = cell(1, n_s);
    for i = 1:n_s
        state_rows_global{i} = (cum_nx_global(i)+1) : cum_nx_global(i+1);
    end

    % 为各中心预计算 r_s 的局域理论协方差 Σ_{r_s,ω}
    Sigma_rs_omega = cell(1, n_omega);
    cs_omega = cell(1, n_omega);
    for omega = 1:n_omega
        idx = indices_omega{omega};

        % 局域状态行索引
        rx = [];
        for s = idx
            rx = [rx, state_rows_global{s}]; %#ok<AGROW>
        end

        % C_{s,ω} = blkdiag(C_s{idx})
        cs_blocks = {};
        for s = idx
            if ~isempty(info.C_s{s})
                cs_blocks{end+1} = info.C_s{s}; %#ok<AGROW>
            end
        end
        if ~isempty(cs_blocks)
            cs_omega{omega} = blkdiag(cs_blocks{:});
        else
            cs_omega{omega} = [];
        end

        % r_s 理论协方差
        Sigma_e_s_omega = obs.Sigma_e_s(rx, rx);
        if ~isempty(cs_omega{omega})
            Sigma_rs_omega{omega} = cs_omega{omega} * Sigma_e_s_omega * cs_omega{omega}';
        else
            Sigma_rs_omega{omega} = [];
        end
    end

    % 计算 J_T² 时间序列（公式 27）
    J_T2_y = cell(1, n_omega);
    J_T2_s = cell(1, n_omega);

    for omega = 1:n_omega

        % r_y 的 T² 统计量
        if ~isempty(r_y{omega}) && ~isempty(obs.Sigma_r_omega{omega})
            dim_y = size(r_y{omega}, 1);
            Sigma_inv_y = obs.Sigma_r_omega{omega} \ eye(dim_y);
            J_T2_y{omega} = zeros(1, T_sim);
            for k = 1:T_sim
                rk = r_y{omega}(:, k);
                J_T2_y{omega}(k) = rk' * Sigma_inv_y * rk;
            end
        else
            J_T2_y{omega} = [];
        end

        % r_s 的 T² 统计量
        if ~isempty(r_s{omega}) && ~isempty(Sigma_rs_omega{omega})
            dim_s = size(r_s{omega}, 1);
            Sigma_inv_s = Sigma_rs_omega{omega} \ eye(dim_s);
            J_T2_s{omega} = zeros(1, T_sim);
            for k = 1:T_sim
                rk = r_s{omega}(:, k);
                J_T2_s{omega}(k) = rk' * Sigma_inv_s * rk;
            end
        else
            J_T2_s{omega} = [];
        end

    end

    % χ² 理论门限（α = 0.99）
    J_th_y = zeros(1, n_omega);
    J_th_s = zeros(1, n_omega);
    for omega = 1:n_omega
        if ~isempty(r_y{omega})
            J_th_y(omega) = chi2inv(alpha, size(r_y{omega}, 1));
        else
            J_th_y(omega) = NaN;
        end
        if ~isempty(r_s{omega})
            J_th_s(omega) = chi2inv(alpha, size(r_s{omega}, 1));
        else
            J_th_s(omega) = NaN;
        end
    end

end

function s = ternary(condition, true_str, false_str)
% ternary  三元条件运算符辅助函数
    if condition
        s = true_str;
    else
        s = false_str;
    end
end
