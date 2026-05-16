function run_experiment_12(watermarks,attack_target,attack_len)
% run_experiment_12  实验12：检测性能与性能损失随攻击强度变化分析
%
% 任务1：检测率、误报率、漏报率 vs 攻击强度 (连续扫描)
% 任务2：性能损失时间轨迹及平均性能损失 vs 攻击强度 (离散强度)

    %% ================= 公共参数与系统建立 =================
    Ts = 1;  rng(2026);

    [G, H, C, D, x_eq, u_eq, y_eq] = Create_shoukong;
    H_ext = [H, eye(4)];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Gw = G - K_KF*C - H*K;
    Hw = K_KF;

    % 攻击公共设置
    FDIA_length = 750;
    ramp_len = attack_len;
    sign_vec = [1; 1];
    start_time_FDIA = 250;          % 攻击开始时间
    attack_start = 250;
    attack_end = 1000;

    % 水印方案列表：索引、名称、嵌入时间
    wm_info = [...
        struct('idx', 0, 'name', '无水印',   'startQW', 2000);   % 无水印
        struct('idx', 3, 'name', '最优弱',   'startQW', 0);    % 弱水印
        struct('idx', 4, 'name', '最优强',   'startQW', 0);    % 强水印
    ];

    % 理论最大攻击向量（来自实验1）
    d_max = attack_target;
    alpha_max = norm(d_max);   % 最大攻击强度 (L2范数)

    %% ---- 辅助函数：为给定水印和攻击目标运行一次仿真 ----
    function [out, Dq] = run_single_sim(wm_idx, wm_startQW, d_target)
        % 配置水印
        if wm_idx > 0
            Cw = watermarks(wm_idx).Cw;
            Dw = watermarks(wm_idx).Dw;
            [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
        else
            Cw = zeros(2,4); Dw = eye(2);
            Gq = zeros(size(Gw)); Hq = zeros(size(Hw));
            Cq = zeros(2,4); Dq = eye(2);
        end
        analog_time = start_time_FDIA + FDIA_length;
        if wm_startQW <= analog_time && wm_idx > 0
            % 有水印时，嵌入时间已在参数中设置，不自动调整
        elseif wm_idx == 0
            wm_startQW = analog_time + 1;   % 无水印时保证不触发
        end

        % 生成攻击序列
        simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, ...
            FDIA_length, d_target, sign_vec, start_time_FDIA, Ts, ramp_len);

        % 生成噪声
        [simin_noise_Wk, simin_noise_Vk, simin_noise_Va, Vk,Va, Wk] = Create_noise_v2(analog_time);
        I_a = eye(length(G));

        % 清理并推送变量
        dynamic_vars = {'Ts','analog_time','start_time_FDIA','FDIA_length','start_time_QW', ...
                        'G','H','C','D','Cj','Dj','K','K_KF','Gw','Hw','H_ext',...
                        'Cw','Dw','Gq','Hq','Cq','Dq',...
                        'simin_FDIA','simin_noise_Vk','simin_noise_Va','simin_noise_Wk','Vk','Wk','I_a','Va',...
                        'x_eq','u_eq','y_eq'};
        for k = 1:length(dynamic_vars)
            if evalin('base', ['exist(''', dynamic_vars{k}, ''',''var'')']), evalin('base', ['clear ', dynamic_vars{k}]); end
        end
        assignin('base','Ts',Ts); assignin('base','analog_time',analog_time);
        assignin('base','start_time_FDIA',start_time_FDIA); assignin('base','FDIA_length',FDIA_length);
        assignin('base','start_time_QW',wm_startQW);
        assignin('base','G',G); assignin('base','H',H); assignin('base','H_ext',H_ext);
        assignin('base','C',C); assignin('base','D',D);
        assignin('base','Cj',Cj); assignin('base','Dj',Dj);
        assignin('base','K',K); assignin('base','K_KF',K_KF);
        assignin('base','Gw',Gw); assignin('base','Hw',Hw);
        assignin('base','Cw',Cw); assignin('base','Dw',Dw);
        assignin('base','Gq',Gq); assignin('base','Hq',Hq);
        assignin('base','Cq',Cq); assignin('base','Dq',Dq);
        assignin('base','simin_FDIA',simin_FDIA);
        assignin('base','simin_noise_Va',simin_noise_Va); assignin('base','simin_noise_Wk',simin_noise_Wk);
        assignin('base','simin_noise_Vk',simin_noise_Vk);
        assignin('base','Vk',Vk); assignin('base','Wk',Wk);
        assignin('base','I_a',I_a); assignin('base','Va',Va);
        assignin('base','x_eq',x_eq); assignin('base','u_eq',u_eq); assignin('base','y_eq',y_eq);

        out = sim('Control_system_v6');
    end

    %% ================= 任务1：检测性能 vs 攻击强度 =================
    fprintf('===== 任务1：检测率/误报率/漏报率 vs 攻击强度 =====\n');

    % 扫描点：均匀取21个λ值
    lambda_vals = linspace(0, 1, 50);   % 可调整为更多点
    n_scan = length(lambda_vals);
    attack_alpha = zeros(n_scan, 1);    % 攻击强度 (L2范数)

    % 存储三维数组：行=强度，列=指标(Pd,Pf,Pm)，第三维=水印方案
    det_perf = zeros(n_scan, 3, length(wm_info));

    % 首先获取每种水印的最优阈值 (调用实验10，不画图)
    eps_opt = zeros(1, length(wm_info));
    for s = 1:length(wm_info)
        exp10.scheme_name = wm_info(s).name;
        exp10.watermark_idx = wm_info(s).idx;
        exp10.start_time_QW = wm_info(s).startQW;
        exp10.start_time_FDIA = start_time_FDIA;
        exp10.FDIA_length = FDIA_length;
        exp10.d_target = d_max;   % 使用最大攻击来校准阈值
        exp10.ramp_len = ramp_len;
        exp10.sign_vec = sign_vec;
        exp10.attack_start = attack_start;
        exp10.attack_end = attack_end;
        exp10.cf = 1;  exp10.cm = 2;  exp10.lambda = 0;
        [~, eps_opt(s)] = run_experiment_10(exp10, watermarks, false);
    end

    % 扫描循环
    for i = 1:n_scan
        d_target = lambda_vals(i) * d_max;
        attack_alpha(i) = norm(d_target);   % 攻击强度
        for s = 1:length(wm_info)
            out = run_single_sim(wm_info(s).idx, wm_info(s).startQW, d_target);
            % 计算残差模平方序列
            r_data = out.r.Data;
            if size(r_data,1)==length(out.r.Time)
                norm_r = sum(r_data.^2,2);
            else
                norm_r = sum(r_data.^2,1)';
            end
            r2_ts = timeseries(norm_r, out.r.Time);
            [Pd, Pf, Pm] = Calculate_DetectionMetrics(r2_ts, eps_opt(s), attack_start, attack_end);
            det_perf(i, :, s) = [Pd, Pf, Pm];
        end
    end

    % 绘制三张图：检测率、误报率、漏报率 vs 攻击强度（每图三条曲线）
    metric_names = {'检测率 P_d', '误报率 P_f', '漏报率 P_m'};
    metric_ylbl = {'P_d', 'P_f', 'P_m'};
    out_dir1 = fullfile('Figures', '12_Detection_Performance');
    if ~exist(out_dir1, 'dir'), mkdir(out_dir1); end

    for m = 1:3
        figure('Color','w');
        hold on;
        for s = 1:length(wm_info)
            plot(attack_alpha, det_perf(:, m, s), 'LineWidth', 1.5, ...
                'DisplayName', wm_info(s).name);
        end
        xlabel('攻击强度 \alpha'); ylabel(metric_ylbl{m});
        title(['攻击强度对 ' metric_names{m} ' 的影响']);
        legend('Location','best'); grid on;
        Run_visualization;
        if exist('Export_fig_paper','file')==2
            Export_fig_paper(gcf, fullfile(out_dir1, sprintf('metric_%d', m)), 5.5);
        else
            saveas(gcf, fullfile(out_dir1, sprintf('metric_%d.png', m)));
        end
        close(gcf);
    end

    %% ================= 任务2：性能损失 vs 攻击强度 =================
    fprintf('===== 任务2：性能损失时间轨迹及平均性能损失 =====\n');

    % 离散10个攻击强度（均匀取0.1到1）
    disc_lambda = linspace(0.1, 1, 10);
    n_disc = length(disc_lambda);
    disc_alpha = zeros(n_disc, 1);
    % 存储每种水印在各个强度下的平均性能损失（用于汇总图）
    disc_loss = cell(1, length(wm_info));
    % 输出文件夹
    out_dir2 = fullfile('Figures', '12_Performance_Loss');
    if ~exist(out_dir2, 'dir'), mkdir(out_dir2); end

    for s = 1:length(wm_info)
        figure('Color','w');
        hold on;
        avg_loss = zeros(n_disc, 1);   % 该水印方案下各强度的平均损失
        for i = 1:n_disc
            d_target = disc_lambda(i) * d_max;
            disc_alpha(i) = norm(d_target);
            out = run_single_sim(wm_info(s).idx, wm_info(s).startQW, d_target);

            % 提取性能时序并计算每个时刻的 ||y_j(k)||^2
            yj_data = out.y_j.Data;
            t_vec = out.y_j.Time(:);
            yj_data = squeeze(yj_data);                % 压缩多余维度
            if isvector(yj_data)
                % 单通道标量，直接平方
                yj_norm_sq = yj_data(:).^2;
            else
                [d1, d2] = size(yj_data);
                if d1 == length(t_vec)
                    yj_norm_sq = sum(yj_data.^2, 2);   % 时间×通道 → 列向量
                elseif d2 == length(t_vec)
                    yj_norm_sq = sum(yj_data.^2, 1)';  % 通道×时间 → 列向量
                else
                    error('无法解析 yj 数据维度。');
                end
            end
            yj_norm_sq = yj_norm_sq(:)';               % 最终转为行向量
            time_vec = t_vec(:)';                       % 时间也转为行向量

            plot(time_vec, yj_norm_sq, 'LineWidth', 1.0, ...
                'DisplayName', sprintf('\\alpha=%.2f', disc_alpha(i)));

            % 计算攻击时段内的平均性能损失
            idx_attack = (time_vec >= attack_start) & (time_vec <= attack_end);
            avg_loss(i) = mean(yj_norm_sq(idx_attack));
        end
        xlabel('时间 t / s'); ylabel('||y_j||^2');
        title(sprintf('%s 性能损失时间轨迹', wm_info(s).name));
        legend('Location','best'); grid on;
        Run_visualization;
        if exist('Export_fig_paper','file')==2
            Export_fig_paper(gcf, fullfile(out_dir2, sprintf('loss_trajectory_%s', wm_info(s).name)), 5.5);
        else
            saveas(gcf, fullfile(out_dir2, sprintf('loss_trajectory_%s.png', wm_info(s).name)));
        end
        close(gcf);
        % 保存该水印方案的平均损失曲线数据
        disc_loss{s} = avg_loss;
    end

    % 绘制平均性能损失 vs 攻击强度汇总图（三条曲线）
    figure('Color','w');
    hold on;
    for s = 1:length(wm_info)
        plot(disc_alpha, disc_loss{s}, 'o-', 'LineWidth', 1.5, ...
            'DisplayName', wm_info(s).name);
    end
    xlabel('攻击强度 \alpha'); ylabel('平均性能损失');
    title('攻击强度对平均性能损失的影响');
    legend('Location','best'); grid on;
    Run_visualization;
    if exist('Export_fig_paper','file')==2
        Export_fig_paper(gcf, fullfile(out_dir2, 'avg_loss_vs_attack'), 5.5);
    else
        saveas(gcf, fullfile(out_dir2, 'avg_loss_vs_attack.png'));
    end
    close(gcf);

end