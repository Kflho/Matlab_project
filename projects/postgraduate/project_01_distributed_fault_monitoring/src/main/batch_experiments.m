%% batch_experiments.m  批量实验总控脚本
%  仪表盘脚本：检查各实验的产出文件，提取关键验收指标，打印汇总表。
%
%  使用方法：
%    1. 逐个运行各实验脚本（在 src/main/ 目录下启动 MATLAB，运行）：
%       >> experiment_01_decentralized_residual
%       >> experiment_02_zero_mean_residual
%       >> experiment_03_t2_detection
%       >> experiment_04_detectability_bound
%       >> experiment_05_coarse_localization
%       >> experiment_06_fine_localization
%    2. 运行本脚本查看全局汇总：
%       >> batch_experiments
%
%  注意：各实验脚本内调用 clear，因此不能在 batch_experiments 中用 run()
%        串联执行——那会清空本脚本的工作区。请手动逐个运行各实验。
%        本脚本仅作为"仪表盘"读取已有产出。
%
%  配置：修改下方的 run_exp 结构体字段为 false 可跳过对应实验的检查。
%
%  依赖：
%    src/lib/     — （本脚本不依赖项目函数，仅读取 .mat 文件）
%    src/scripts/ — （同上）
%    utils/       — （同上）

clear; clc;

% ---- 添加路径 ----
addpath(genpath('../../../../../utils/'));
addpath(genpath('../lib/'));
addpath(genpath('../scripts/'));

%% ============================================================
%  配置开关
% ============================================================
%  设置需要检查的实验（true = 检查，false = 跳过）
%  不影响实验的实际运行，仅控制本仪表盘的展示范围。

run_exp = struct(...
    'exp_01_decentralized',  true, ...
    'exp_02_zero_mean',      true, ...
    'exp_03_t2_detection',   true, ...
    'exp_04_detectability',  true, ...
    'exp_05_coarse_loc',     true, ...
    'exp_06_fine_loc',       true  ...
);

%% ============================================================
%  实验定义（元数据表）
% ============================================================
%  每个实验的脚本名称、输出目录、验收指标提取函数

experiments = struct(...
    'num',         {1, 2, 3, 4, 5, 6}, ...
    'name',        {'Decentralized Residual', ...
                    'Zero Mean Residual', ...
                    'T2 Detection', ...
                    'Detectability Bound', ...
                    'Coarse Localization', ...
                    'Fine Localization'}, ...
    'script',      {'experiment_01_decentralized_residual', ...
                    'experiment_02_zero_mean_residual', ...
                    'experiment_03_t2_detection', ...
                    'experiment_04_detectability_bound', ...
                    'experiment_05_coarse_localization', ...
                    'experiment_06_fine_localization'}, ...
    'output_dir',  {'../../outputs/experiment_01_decentralized_residual/', ...
                    '../../outputs/experiment_02_zero_mean_residual/', ...
                    '../../outputs/experiment_03_t2_detection/', ...
                    '../../outputs/experiment_04_detectability_bound/', ...
                    '../../outputs/experiment_05_coarse_localization/', ...
                    '../../outputs/experiment_06_fine_localization/'}, ...
    'config_field', {'exp_01_decentralized', ...
                     'exp_02_zero_mean', ...
                     'exp_03_t2_detection', ...
                     'exp_04_detectability', ...
                     'exp_05_coarse_loc', ...
                     'exp_06_fine_loc'}, ...
    'description',  {'各中心独立计算残差与全局一致', ...
                     '无故障时残差期望值为零', ...
                     'T^2 统计量检测与零误报验证', ...
                     '故障幅值—检出率曲线与可检测性边界', ...
                     '切断交互链路锁定故障计算中心', ...
                     '交叉估计锁定故障子系统'} ...
);

n_experiments = length(experiments);

%% ============================================================
%  打印使用说明
% ============================================================
fprintf('======================================================================\n');
fprintf('  BATCH EXPERIMENTS — 批量实验仪表盘\n');
fprintf('======================================================================\n\n');
fprintf('  本脚本不自动运行各实验（各实验含 clear 会清空工作区）。\n');
fprintf('  请在 src/main/ 目录下逐个运行实验脚本，然后运行本脚本查看汇总。\n\n');
fprintf('  运行命令（在 src/main/ 下逐条执行）：\n');
for i = 1:n_experiments
    fprintf('    >> %s\n', experiments(i).script);
end
fprintf('\n');

%% ============================================================
%  打印运行配置
% ============================================================
fprintf('----------------------------------------------------------------------\n');
fprintf('  当前检查配置（修改 batch_experiments.m 中 run_exp 开关调整）：\n\n');
fprintf('  %-4s %-30s %s\n', '#', '实验名称', '检查开关');
fprintf('  %-4s %-30s %s\n', '---', '------------------------------', '--------');

config_fields = fieldnames(run_exp);
for i = 1:n_experiments
    field_name = experiments(i).config_field;
    enabled = run_exp.(field_name);
    if enabled
        status_str = 'ON';
    else
        status_str = 'OFF (跳过)';
    end
    fprintf('  %-4d %-30s %s\n', experiments(i).num, experiments(i).name, status_str);
end
fprintf('\n');

%% ============================================================
%  检查各实验产出状态
% ============================================================
fprintf('======================================================================\n');
fprintf('  实验产出检查\n');
fprintf('======================================================================\n\n');

for i = 1:n_experiments
    exp = experiments(i);

    % 检查是否启用
    field_name = exp.config_field;
    if ~run_exp.(field_name)
        experiments(i).status = 'SKIPPED';
        experiments(i).status_code = 0;
        continue;
    end

    % 检查 results.mat 是否存在
    results_file = [exp.output_dir 'data' filesep 'results.mat'];
    if exist(results_file, 'file') == 2
        experiments(i).status = 'COMPLETED';
        experiments(i).status_code = 1;
        experiments(i).results_file = results_file;
    else
        % 检查目录是否存在（可能是脚本运行但产出路径不同）
        if exist(exp.output_dir, 'dir') == 7
            experiments(i).status = 'PARTIAL';
            experiments(i).status_code = 2;
            experiments(i).results_file = '';
        else
            experiments(i).status = 'PENDING';
            experiments(i).status_code = -1;
            experiments(i).results_file = '';
        end
    end
end

%% ============================================================
%  加载各实验关键指标
% ============================================================
for i = 1:n_experiments
    exp = experiments(i);
    if exp.status_code ~= 1
        % 未完成，无指标可提取
        experiments(i).metric_str = '--';
        experiments(i).verdict = '--';
        continue;
    end

    try
        data = load(exp.results_file);
    catch
        experiments(i).metric_str = '加载失败';
        experiments(i).verdict = 'ERROR';
        continue;
    end

    switch exp.num

        case 1  % ---- 实验 01：分布式残差独立计算 ----
            %   max_err_y, max_err_s: 各中心局域与全局残差的最大偏差
            if isfield(data, 'max_err_y') && isfield(data, 'max_err_s')
                worst_y = max(data.max_err_y(:));
                worst_s = max(data.max_err_s(:));
                tol = 1e-12;
                if worst_y < tol && worst_s < tol
                    experiments(i).verdict = 'PASS';
                else
                    experiments(i).verdict = 'FAIL';
                end
                experiments(i).metric_str = sprintf('max err_y = %.2e,  max err_s = %.2e', ...
                    worst_y, worst_s);
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少 max_err_y/max_err_s';
            end

        case 2  % ---- 实验 02：零均值残差验证 ----
            %   mean_results: 含各中心各分量的样本均值与 3σ 界
            if isfield(data, 'mean_results')
                mr = data.mean_results;
                all_passed = true;
                worst_ratio = 0;
                for m = 1:length(mr)
                    for j = 1:mr(m).n_y_dim
                        ratio = abs(mr(m).mean_y(j)) / mr(m).bound_y(j);
                        if ratio > worst_ratio, worst_ratio = ratio; end
                        if ratio >= 1, all_passed = false; end
                    end
                    for j = 1:mr(m).n_s_dim
                        ratio = abs(mr(m).mean_s(j)) / mr(m).bound_s(j);
                        if ratio > worst_ratio, worst_ratio = ratio; end
                        if ratio >= 1, all_passed = false; end
                    end
                end
                if all_passed
                    experiments(i).verdict = 'PASS';
                else
                    experiments(i).verdict = 'FAIL';
                end
                experiments(i).metric_str = sprintf('max |mean|/bound = %.2f', worst_ratio);
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少 mean_results';
            end

        case 3  % ---- 实验 03：T² 检测与零误报 ----
            %   fa_results: 各中心全序列/稳态误报次数与误报率
            %   验收标准：稳态误报率 ≈ 理论值 1%，允许 ±2% 波动
            if isfield(data, 'fa_results') && isfield(data, 'alpha')
                fr = data.fa_results;
                theory_far = (1 - data.alpha) * 100;
                tolerance = 2.0;
                all_ok = true;
                worst_far = 0;
                for m = 1:length(fr)
                    if isfield(fr, 'far_y_steady') && fr(m).far_y_steady > 0
                        far_y = fr(m).far_y_steady;
                        if far_y > worst_far, worst_far = far_y; end
                        if far_y > theory_far + tolerance, all_ok = false; end
                    end
                    if isfield(fr, 'far_s_steady') && fr(m).far_s_steady > 0
                        far_s = fr(m).far_s_steady;
                        if far_s > worst_far, worst_far = far_s; end
                        if far_s > theory_far + tolerance, all_ok = false; end
                    end
                end
                if all_ok
                    experiments(i).verdict = 'PASS';
                else
                    experiments(i).verdict = 'FAIL';
                end
                if worst_far > 0
                    experiments(i).metric_str = sprintf('稳态 max FAR = %.2f%% (理论 %.2f%%)', ...
                        worst_far, theory_far);
                else
                    experiments(i).metric_str = sprintf('FAR 无数据 (理论 %.2f%%)', theory_far);
                end
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少 fa_results/alpha';
            end

        case 4  % ---- 实验 04：故障可检测性边界 ----
            %   mag_emp_bound_sensor, mag_emp_bound_actuator: 经验边界
            %   detect_rate_sensor, detect_rate_actuator: 检出率曲线
            if isfield(data, 'mag_emp_bound_sensor') && isfield(data, 'mag_emp_bound_actuator')
                bound_y = data.mag_emp_bound_sensor;
                bound_u = data.mag_emp_bound_actuator;
                sensor_ok = isfinite(bound_y) && bound_y < 1e6;
                actuator_ok = isfinite(bound_u) && bound_u < 1e6;

                if isfield(data, 'detect_rate_sensor')
                    max_rate_sensor = max(data.detect_rate_sensor);
                else
                    max_rate_sensor = NaN;
                end
                if isfield(data, 'detect_rate_actuator')
                    max_rate_actuator = max(data.detect_rate_actuator);
                else
                    max_rate_actuator = NaN;
                end

                if sensor_ok && actuator_ok
                    experiments(i).verdict = 'PASS';
                elseif sensor_ok || actuator_ok
                    experiments(i).verdict = 'PARTIAL';
                else
                    experiments(i).verdict = 'FAIL';
                end

                parts = {};
                if sensor_ok
                    parts{end+1} = sprintf('传感器边界=%.4f', bound_y);
                else
                    parts{end+1} = sprintf('传感器最大检出率=%.0f%%', max_rate_sensor * 100);
                end
                if actuator_ok
                    parts{end+1} = sprintf('执行器边界=%.4f', bound_u);
                else
                    parts{end+1} = sprintf('执行器最大检出率=%.0f%%', max_rate_actuator * 100);
                end
                experiments(i).metric_str = strjoin(parts, ', ');
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少边界数据';
            end

        case 5  % ---- 实验 05：粗定位 ----
            %   result: 含 is_correct, accuracy, fault_subsys_list 等
            if isfield(data, 'result') && isfield(data, 'accuracy')
                acc = data.accuracy;
                n_corr = data.n_correct;
                n_total = data.n_fault_cases;
                if acc >= 75
                    experiments(i).verdict = 'PASS';
                elseif acc >= 50
                    experiments(i).verdict = 'PARTIAL';
                else
                    experiments(i).verdict = 'FAIL';
                end
                experiments(i).metric_str = sprintf('accuracy = %d/%d = %.1f%%', ...
                    n_corr, n_total, acc);
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少 result/accuracy';
            end

        case 6  % ---- 实验 06：精定位 ----
            %   fine_results, coarse_results, accuracy, n_correct, n_fault_cases
            if isfield(data, 'accuracy') && isfield(data, 'n_correct')
                acc = data.accuracy;
                n_corr = data.n_correct;
                n_total = data.n_fault_cases;
                if acc >= 75
                    experiments(i).verdict = 'PASS';
                elseif acc >= 50
                    experiments(i).verdict = 'PARTIAL';
                else
                    experiments(i).verdict = 'FAIL';
                end
                experiments(i).metric_str = sprintf('accuracy = %d/%d = %.1f%%', ...
                    n_corr, n_total, acc);
            else
                experiments(i).verdict = 'NODATA';
                experiments(i).metric_str = '缺少 accuracy/n_correct';
            end

        otherwise
            experiments(i).verdict = 'UNKNOWN';
            experiments(i).metric_str = '未识别的实验编号';
    end

end

%% ============================================================
%  打印汇总表
% ============================================================
fprintf('======================================================================\n');
fprintf('  BATCH EXPERIMENTS — 验收汇总\n');
fprintf('======================================================================\n\n');

% 表头
fprintf('  %-4s %-28s %-14s %-8s %s\n', ...
    '#', 'Experiment', 'Status', 'Verdict', 'Key Metric');
fprintf('  %-4s %-28s %-14s %-8s %s\n', ...
    '----', '----------------------------', '--------------', '--------', ...
    '--------------------------------------------------');

% 逐行打印
for i = 1:n_experiments
    exp = experiments(i);

    % 状态着色标记（纯文本环境使用符号前缀）
    switch exp.status
        case 'COMPLETED'
            status_disp = '[COMPLETED]';
        case 'PENDING'
            status_disp = '[PENDING]';
        case 'PARTIAL'
            status_disp = '[PARTIAL]';
        case 'SKIPPED'
            status_disp = '[SKIPPED]';
        otherwise
            status_disp = ['[' exp.status ']'];
    end

    fprintf('  %-4d %-28s %-14s %-8s %s\n', ...
        exp.num, exp.name, status_disp, exp.verdict, exp.metric_str);
end

fprintf('\n');

%% ============================================================
%  统计总览
% ============================================================
n_completed = sum([experiments.status_code] == 1);
n_pending   = sum([experiments.status_code] == -1);
n_partial   = sum([experiments.status_code] == 2);
n_skipped   = sum([experiments.status_code] == 0);

fprintf('----------------------------------------------------------------------\n');
fprintf('  统计：完成 %d / %d，待运行 %d，部分产出 %d，跳过 %d\n', ...
    n_completed, n_experiments, n_pending, n_partial, n_skipped);

% 判定汇总
pass_count = sum(strcmp({experiments.verdict}, 'PASS'));
fail_count = sum(strcmp({experiments.verdict}, 'FAIL'));
partial_count = sum(strcmp({experiments.verdict}, 'PARTIAL'));
nodata_count = sum(strcmp({experiments.verdict}, 'NODATA'));

if n_completed > 0
    fprintf('  验收判定：通过 %d，未通过 %d，部分通过 %d，无数据 %d\n', ...
        pass_count, fail_count, partial_count, nodata_count);
end
fprintf('\n');

%% ============================================================
%  打印待运行实验的运行指令
% ============================================================
pending_list = find([experiments.status_code] ~= 1);
pending_list = pending_list([experiments(pending_list).status_code] ~= 0);  % 排除 Skipped

if ~isempty(pending_list)
    fprintf('======================================================================\n');
    fprintf('  待运行实验 — 请在 src/main/ 目录下逐条执行：\n');
    fprintf('======================================================================\n\n');
    for idx = pending_list
        exp = experiments(idx);
        fprintf('  [%s] %s\n', exp.status, exp.script);
        fprintf('        %s\n', exp.description);
        fprintf('        >> %s\n\n', exp.script);
    end
end

%% ============================================================
%  实验间依赖关系提示
% ============================================================
fprintf('----------------------------------------------------------------------\n');
fprintf('  实验依赖关系（建议运行顺序）：\n\n');
fprintf('  实验 01 → 02 → 03 → 04 → 05 → 06\n');
fprintf('  每个实验独立完成离线设计链路（Model 1→2→组装→LMI→拆分），\n');
fprintf('  因此可独立运行。但实验 02 依赖实验 01 确认残差正确性，\n');
fprintf('  实验 03 依赖实验 02 确认零均值基线，建议按序运行。\n');
fprintf('\n');

%% ============================================================
%  产出目录结构概览
% ============================================================
fprintf('----------------------------------------------------------------------\n');
fprintf('  产出目录结构：\n\n');
fprintf('  outputs/\n');
for i = 1:n_experiments
    exp = experiments(i);
    dir_name = strrep(exp.output_dir, '../../outputs/', '');
    dir_name = strrep(dir_name, '/', '');
    if exp.status_code == 1
        marker = '[OK]';
    elseif exp.status_code == 2
        marker = '[PARTIAL]';
    elseif exp.status_code == 0
        marker = '[SKIP]';
    else
        marker = '[--]';
    end
    fprintf('    %-6s %s\n', marker, dir_name);
    if exp.status_code == 1
        fprintf('           ├── data/results.mat\n');
        fprintf('           └── figures/*.png, *.fig\n');
    elseif exp.status_code == 2
        fprintf('           └── (目录存在，但缺少 data/results.mat)\n');
    else
        fprintf('           └── (尚未创建)\n');
    end
end
fprintf('\n');

%% ============================================================
%  结束
% ============================================================
fprintf('======================================================================\n');
fprintf('  batch_experiments 运行完毕。\n');
fprintf('  请根据上述汇总逐项运行待完成的实验，运行后再次执行本脚本\n');
fprintf('  以查看更新后的汇总。\n');
fprintf('======================================================================\n');
