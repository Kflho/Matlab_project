%% show_liquid_level.m  正常与受攻击水箱液位时间变化对比
%  目标：展示四容水箱系统在正常工况与故障注入后各水箱液位偏差
%        的时间演化对比。故障通过执行器偏移注入（泵1受攻击），
%        直接改变控制输入，从而影响液位动态。
%
%  可视化产出：
%    1. 2×2 子图：每个水箱正常（蓝实线）vs 故障（红虚线）液位对比
%    2. 组合图：全部 4 个水箱的液位偏差（故障 - 正常）
%
%  依赖：
%    src/scripts/ — create_model_1
%    src/lib/     — inject_fault
%    utils/       — create_controlled_system, calculate_lqr, create_noise_v2,
%                   run_visualization

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  1. 加载模型与控制器
% ============================================================
fprintf('========== show_liquid_level：正常 vs 受攻击液位对比 ==========\n\n');
fprintf('--- 1. 加载模型与控制器 ---\n');

% 1a. 加载 model 1（四容水箱交互导向模型）
create_model_1;

% 1b. 被控系统与 LQR 控制器
[A_g_sys, B_g_sys, C_g_sys, D_g_sys, x_eq, u_eq, y_eq] = create_controlled_system();
K = calculate_lqr(A_g_sys, B_g_sys);

fprintf('  被控系统: A=%d×%d, B=%d×%d, C=%d×%d\n', ...
    size(A_g_sys,1), size(A_g_sys,2), size(B_g_sys,1), size(B_g_sys,2), ...
    size(C_g_sys,1), size(C_g_sys,2));
fprintf('  LQR 增益 K: %d×%d\n', size(K,1), size(K,2));

% 1c. 闭环稳定性验证
eig_cl = abs(eig(A_g_sys - B_g_sys * K));
fprintf('  闭环谱半径: %.6f', max(eig_cl));
if all(eig_cl < 1)
    fprintf('  (稳定)\n');
else
    fprintf('  (不稳定!)\n');
end

% ---- 全局维度 ----
N_x = size(A_g_sys, 1);     % 4（四水箱状态）
N_u = size(B_g_sys, 2);     % 2（两泵输入）
N_y = size(C_g_sys, 1);     % 2（两传感器输出）

% ---- 状态索引（子系统 → 全局状态偏移）----
cum_n_x = [0, cumsum(n_x)];
state_rows = cell(1, n_s);
for i = 1:n_s
    state_rows{i} = (cum_n_x(i) + 1) : cum_n_x(i + 1);
end

% ---- 组装全局噪声协方差 ----
Sigma_w_full = blkdiag(Sigma_w{:});
has_output = (n_y > 0);
Sigma_v_nonempty = Sigma_v(has_output);
Sigma_v_full = blkdiag(Sigma_v_nonempty{:});

fprintf('  Sigma_w = %d×%d,  Sigma_v = %d×%d\n', ...
    size(Sigma_w_full,1), size(Sigma_w_full,2), ...
    size(Sigma_v_full,1), size(Sigma_v_full,2));

%% ============================================================
%  2. 仿真参数与噪声序列生成
% ============================================================
fprintf('\n--- 2. 仿真参数与噪声序列 ---\n');

T_sim   = 500;      % 仿真步数
k_fault = 200;      % 故障注入起始时刻
fault_magnitude = 0.5;          % 故障幅值
fault_subsys    = 1;            % 故障目标子系统（水箱1）
fault_type      = 'sensor';     % 故障类型（同时仿真执行器效应以影响液位）

fprintf('  T_sim = %d,  k_fault = %d\n', T_sim, k_fault);
fprintf('  故障: %s 故障, 子系统 %d, 幅值 %.2f\n', fault_type, fault_subsys, fault_magnitude);

% 固定随机种子，保证可复现
rng(42);

% 过程噪声 w_k（4 维）
[~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);   % 4 × T_sim

% 测量噪声 v_k（2 维）
[~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);   % 2 × T_sim

fprintf('  w_seq = %d×%d,  v_seq = %d×%d\n', ...
    size(w_seq,1), size(w_seq,2), size(v_seq,1), size(v_seq,2));

%% ============================================================
%  3. 正常工况 LQR 闭环仿真（无故障）
% ============================================================
fprintf('\n--- 3. 正常工况仿真 ---\n');

x_seq_normal = zeros(N_x, T_sim);
u_seq_normal = zeros(N_u, T_sim);
y_seq_normal = zeros(N_y, T_sim);

x_k = zeros(N_x, 1);
for k = 1:T_sim
    u_k = -K * x_k;
    u_seq_normal(:, k) = u_k;
    y_seq_normal(:, k) = C_g_sys * x_k + v_seq(:, k);
    x_seq_normal(:, k) = x_k;

    if k < T_sim
        x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
    end
end

fprintf('  正常仿真完成: T_sim=%d\n', T_sim);
fprintf('  x_seq = %d×%d,  u_seq = %d×%d,  y_seq = %d×%d\n', ...
    size(x_seq_normal,1), size(x_seq_normal,2), ...
    size(u_seq_normal,1), size(u_seq_normal,2), ...
    size(y_seq_normal,1), size(y_seq_normal,2));

%% ============================================================
%  4. 故障注入仿真（执行器偏移 + 传感器偏置）
% ============================================================
%  执行器故障通过修改控制输入 u_k(1) 注入（泵1受攻击），
%  直接影响状态动态方程 x_{k+1} = A·x_k + B·(u_k + f_u) + w_k，
%  从而改变各水箱的液位演化轨迹。
%  传感器故障通过修改测量输出 y_k(1) 注入（水箱1传感器被篡改），
%  用于验证故障检测逻辑，但不影响液位动态。
fprintf('\n--- 4. 故障注入仿真 ---\n');

% 重新固定种子以使用相同的噪声序列
rng(42);
[~, sim_w] = create_noise_v2(T_sim, diag(Sigma_w_full)');
w_seq = squeeze(sim_w.Data);
[~, sim_v] = create_noise_v2(T_sim, diag(Sigma_v_full)');
v_seq = squeeze(sim_v.Data);

x_seq_faulty = zeros(N_x, T_sim);
u_seq_faulty = zeros(N_u, T_sim);
y_seq_faulty = zeros(N_y, T_sim);

f_u_vec = [fault_magnitude; 0];   % 执行器故障：仅泵1受攻击

x_k = zeros(N_x, 1);
for k = 1:T_sim
    u_k = -K * x_k;

    % ---- 故障注入（k >= k_fault）----
    if k >= k_fault
        % 执行器故障：泵1 控制量被篡改
        u_k = u_k + f_u_vec;
    end

    u_seq_faulty(:, k) = u_k;
    y_seq_faulty(:, k) = C_g_sys * x_k + v_seq(:, k);

    % 传感器故障：水箱1 测量值被篡改（叠加偏差）
    if k >= k_fault
        y_seq_faulty(fault_subsys, k) = y_seq_faulty(fault_subsys, k) + fault_magnitude;
    end

    x_seq_faulty(:, k) = x_k;

    if k < T_sim
        x_k = A_g_sys * x_k + B_g_sys * u_k + w_seq(:, k);
    end
end

fprintf('  故障仿真完成: 故障注入时刻 k ≥ %d\n', k_fault);
fprintf('  执行器故障: u(1) += %.2f（泵1）\n', fault_magnitude);
fprintf('  传感器故障: y(1) += %.2f（水箱1）\n', fault_magnitude);

%% ============================================================
%  5. 使用 inject_fault 函数生成故障序列（传感器故障视角）
% ============================================================
%  对正常仿真序列调用 inject_fault，获得仅含传感器故障的输出序列。
%  此序列供后续故障检测实验使用，不影响本脚本的液位对比可视化。
fprintf('\n--- 5. inject_fault 传感器故障序列 ---\n');

[y_faulty_sensor, u_faulty_sensor] = inject_fault(...
    y_seq_normal, u_seq_normal, 'sensor', fault_subsys, fault_magnitude, k_fault);

fprintf('  传感器故障序列已生成（仅影响 y，不影响 x）。\n');

%% ============================================================
%  6. 液位统计概要
% ============================================================
fprintf('\n--- 6. 液位统计概要 ---\n');

tank_names = {'水箱 1（有传感器）', '水箱 2（有传感器）', ...
              '水箱 3（无传感器）', '水箱 4（无传感器）'};

fprintf('  %-22s %12s %12s %12s\n', '水箱', '正常均值', '故障均值', '均值偏差');
fprintf('  %-22s %12s %12s %12s\n', '----', '------', '------', '------');
for i = 1:n_s
    normal_mean = mean(x_seq_normal(i, :));
    faulty_mean = mean(x_seq_faulty(i, :));
    fprintf('  %-22s %12.4f %12.4f %12.4f\n', ...
        tank_names{i}, normal_mean, faulty_mean, faulty_mean - normal_mean);
end

% 稳态比较（故障注入后，排除瞬态）
k_steady_start = k_fault + 50;  % 给系统 50 步进入故障稳态
if k_steady_start > T_sim
    k_steady_start = k_fault + 1;
end
fprintf('\n  故障注入后稳态均值（k=%d~%d）:\n', k_steady_start, T_sim);
for i = 1:n_s
    normal_steady = mean(x_seq_normal(i, k_steady_start:end));
    faulty_steady = mean(x_seq_faulty(i, k_steady_start:end));
    fprintf('    %s: 正常 %.4f,  故障 %.4f,  偏差 %.4f\n', ...
        tank_names{i}, normal_steady, faulty_steady, faulty_steady - normal_steady);
end

%% ============================================================
%  7. 可视化输出路径
% ============================================================
out_pic = '../../outputs/show_liquid_level/figures/';
if ~exist(out_pic, 'dir'), mkdir(out_pic); end

%% ============================================================
%  8. 图1：2×2 子图 — 各水箱正常 vs 故障液位对比
% ============================================================
fprintf('\n--- 7. 绘制 2×2 液位对比图 ---\n');

t_vec = (0:T_sim-1);

figh_levels = figure('Name', '正常 vs 受攻击液位对比', 'NumberTitle', 'off');
set(figh_levels, 'Position', [100, 100, 1100, 800]);

for i = 1:n_s
    subplot(2, 2, i);
    hold on;

    % 正常液位（蓝实线）
    plot(t_vec, x_seq_normal(i, :), 'b-', 'LineWidth', 1.2);
    % 故障液位（红虚线）
    plot(t_vec, x_seq_faulty(i, :), 'r--', 'LineWidth', 1.2);
    % 故障注入时刻标记
    xline(k_fault, 'k:', 'LineWidth', 1.5);

    hold off;

    xlabel('步数 k');
    ylabel(sprintf('液位偏差 x_%d', i));
    title(sprintf('%s', tank_names{i}));
    legend({'正常（无故障）', '受攻击（故障注入）', ...
        sprintf('故障注入 k=%d', k_fault)}, ...
        'Location', 'best');

    % 标注传感器有无
    if n_y(i) > 0
        text_pos_x = T_sim * 0.02;
        text_pos_y = max(x_seq_normal(i, :)) * 0.85;
        text(text_pos_x, text_pos_y, '有传感器', 'FontSize', 8, ...
            'Color', [0 0.6 0], 'FontWeight', 'bold');
    else
        text_pos_x = T_sim * 0.02;
        text_pos_y = max(x_seq_normal(i, :)) * 0.85;
        text(text_pos_x, text_pos_y, '无传感器', 'FontSize', 8, ...
            'Color', [0.6 0.6 0.6], 'FontWeight', 'bold');
    end
end

sgtitle(sprintf(['正常 vs 受攻击水箱液位对比\n' ...
    '执行器故障（泵1 +%.2f）+ 传感器故障（水箱1 +%.2f），k_{fault}=%d'], ...
    fault_magnitude, fault_magnitude, k_fault));

run_visualization(figh_levels);

saveas(figh_levels, [out_pic 'liquid_level_comparison.png']);
saveas(figh_levels, [out_pic 'liquid_level_comparison.fig']);
fprintf('  已保存: liquid_level_comparison.png / .fig\n');

%% ============================================================
%  9. 图2：各水箱液位偏差（故障 - 正常）叠加图
% ============================================================
fprintf('\n--- 8. 绘制液位偏差叠加图 ---\n');

figh_deviation = figure('Name', '液位偏差（故障 - 正常）', 'NumberTitle', 'off');
set(figh_deviation, 'Position', [150, 150, 900, 500]);

delta_x = x_seq_faulty - x_seq_normal;

hold on;
colors = lines(n_s);
for i = 1:n_s
    plot(t_vec, delta_x(i, :), 'Color', colors(i, :), 'LineWidth', 1.2);
end
xline(k_fault, 'k:', 'LineWidth', 1.5);
hold off;

xlabel('步数 k');
ylabel('液位偏差 \Delta x = x_{faulty} - x_{normal}');
title(sprintf(['各水箱液位偏差时间演化\n' ...
    '执行器故障（泵1 +%.2f）k ≥ %d'], fault_magnitude, k_fault));

legend_str = cell(1, n_s);
for i = 1:n_s
    legend_str{i} = sprintf('水箱 %d', i);
end
legend_str{end+1} = sprintf('故障注入 k=%d', k_fault);
legend(legend_str, 'Location', 'best');

run_visualization(figh_deviation);

saveas(figh_deviation, [out_pic 'liquid_level_deviation.png']);
saveas(figh_deviation, [out_pic 'liquid_level_deviation.fig']);
fprintf('  已保存: liquid_level_deviation.png / .fig\n');

%% ============================================================
%  10. 图3：正常状态下液位时间序列（无故障基线）
% ============================================================
fprintf('\n--- 9. 绘制正常液位基线图 ---\n');

figh_normal = figure('Name', '正常液位基线', 'NumberTitle', 'off');
set(figh_normal, 'Position', [200, 200, 900, 400]);

hold on;
colors = lines(n_s);
for i = 1:n_s
    plot(t_vec, x_seq_normal(i, :), 'Color', colors(i, :), 'LineWidth', 1.2);
end
hold off;

xlabel('步数 k');
ylabel('液位偏差 x_i');
title('正常工况下各水箱液位偏差时间序列（LQR 闭环，无故障）');

leg_str = cell(1, n_s);
for i = 1:n_s
    leg_str{i} = sprintf('水箱 %d', i);
end
legend(leg_str, 'Location', 'best');

run_visualization(figh_normal);

saveas(figh_normal, [out_pic 'liquid_level_normal.png']);
saveas(figh_normal, [out_pic 'liquid_level_normal.fig']);
fprintf('  已保存: liquid_level_normal.png / .fig\n');

%% ============================================================
%  11. 图4：受攻击状态下液位时间序列
% ============================================================
fprintf('\n--- 10. 绘制受攻击液位图 ---\n');

figh_faulty = figure('Name', '受攻击液位', 'NumberTitle', 'off');
set(figh_faulty, 'Position', [250, 250, 900, 400]);

hold on;
for i = 1:n_s
    plot(t_vec, x_seq_faulty(i, :), 'Color', colors(i, :), 'LineWidth', 1.2);
end
xline(k_fault, 'k:', 'LineWidth', 1.5);
hold off;

xlabel('步数 k');
ylabel('液位偏差 x_i');
title(sprintf(['受攻击工况下各水箱液位偏差时间序列\n' ...
    '执行器故障（泵1 +%.2f, k ≥ %d）+ 传感器故障（水箱1 +%.2f）'], ...
    fault_magnitude, k_fault, fault_magnitude));

leg_str = cell(1, n_s);
for i = 1:n_s
    leg_str{i} = sprintf('水箱 %d', i);
end
leg_str{end+1} = sprintf('故障注入 k=%d', k_fault);
legend(leg_str, 'Location', 'best');

run_visualization(figh_faulty);

saveas(figh_faulty, [out_pic 'liquid_level_faulty.png']);
saveas(figh_faulty, [out_pic 'liquid_level_faulty.fig']);
fprintf('  已保存: liquid_level_faulty.png / .fig\n');

%% ============================================================
%  12. 液位偏差数值报告
% ============================================================
fprintf('\n--- 11. 液位偏差详细报告 ---\n');

fprintf('\n  故障注入时刻 k_fault = %d\n', k_fault);
fprintf('  执行器故障幅值: %.4f（泵1）\n', fault_magnitude);
fprintf('  传感器故障幅值: %.4f（水箱1 测量值）\n\n', fault_magnitude);

% 逐水箱分析
for i = 1:n_s
    % 故障前（k_fault 前 10 步）均值偏差
    pre_start = max(1, k_fault - 50);
    pre_end   = k_fault - 1;
    pre_dev   = mean(abs(delta_x(i, pre_start:pre_end)));

    % 故障后稳态均值偏差
    post_dev  = mean(abs(delta_x(i, k_steady_start:end)));
    post_mean = mean(delta_x(i, k_steady_start:end));
    post_max  = max(abs(delta_x(i, k_steady_start:end)));

    fprintf('  水箱 %d (%s):\n', i, tank_names{i});
    fprintf('    故障前平均偏差: %.6f（应接近 0）\n', pre_dev);
    fprintf('    故障后稳态均值: %.4f（符号 %s：液位%s升）\n', ...
        post_mean, sign_str(post_mean), ...
        ternary(post_mean > 0, '上', '下'));
    fprintf('    故障后最大偏差: %.4f\n', post_max);
    fprintf('    故障后稳态 RMS:  %.4f\n', rms(delta_x(i, k_steady_start:end)));
end

fprintf('\n  注：仅执行器故障（泵1 +%.2f）直接影响液位动态。\n', fault_magnitude);
fprintf('       传感器故障（水箱1 测量 +%.2f）影响 y 序列，\n', fault_magnitude);
fprintf('       用于后续故障检测实验，不影响液位演化（全状态反馈控制）。\n');

%% ============================================================
%  13. 产出列表
% ============================================================
fprintf('\n--- 12. 产出汇总 ---\n');

fprintf('  输出目录: %s\n', out_pic);
fprintf('  产出文件:\n');
fprintf('    liquid_level_comparison.png  — 2×2 子图：正常 vs 故障液位对比\n');
fprintf('    liquid_level_comparison.fig\n');
fprintf('    liquid_level_deviation.png   — 叠加图：全部水箱液位偏差\n');
fprintf('    liquid_level_deviation.fig\n');
fprintf('    liquid_level_normal.png      — 正常液位基线（4 线叠加）\n');
fprintf('    liquid_level_normal.fig\n');
fprintf('    liquid_level_faulty.png      — 受攻击液位（4 线叠加）\n');
fprintf('    liquid_level_faulty.fig\n');

fprintf('\n========== show_liquid_level 完成 ==========\n');

%% ============================================================
%  辅助函数（内联）
% ============================================================

function s = sign_str(x)
    % 返回数值符号的字符串表示
    if x > 0
        s = '+';
    elseif x < 0
        s = '-';
    else
        s = '0';
    end
end

function r = ternary(cond, t_val, f_val)
    % 三元条件运算符的 MATLAB 等价实现
    if cond
        r = t_val;
    else
        r = f_val;
    end
end
