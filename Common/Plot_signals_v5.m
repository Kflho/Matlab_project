function Plot_signals_v5(xx, name, Fig_title, mode, axis_labels, custom_labels)
    % 功能：自动识别维度，提取时间轴，支持自定义坐标轴标签及图例名称（支持上下标渲染）
    % 参数：
    %   xx: 数据 (timeseries 或 矩阵)
    %   name: 默认信号名前缀 (如 'r' 则生成 r1, r2...)
    %   Fig_title: 图像标题
    %   mode: 模式 (1:叠加, 2:分栏, 3:单独)
    %   axis_labels: 坐标轴标签 {'X轴', 'Y轴'}
    %   custom_labels: 自定义图例/信号名称 ["信号1", "信号2", ...]

    % 1. 输入参数处理
    if nargin < 2 || isempty(name), name = 'xx'; end
    if nargin < 3 || isempty(Fig_title), Fig_title = name; end
    if nargin < 4 || isempty(mode), mode = 1; end 

    % 处理自定义坐标轴标签 (axis_labels)
    custom_xlabel = '';
    custom_ylabel = '';
    if nargin >= 5 && iscell(axis_labels) && length(axis_labels) >= 2
        custom_xlabel = axis_labels{1};
        custom_ylabel = axis_labels{2};
    end

    % === 学术论文绘图字体规范设置 ===
    font_name = 'Times New Roman'; 
    fs_axis   = 12; 
    fs_label  = 14; 
    fs_legend = 12; 
    fs_title  = 16; 
    fs_sgtitle= 18; 
    line_w    = 1.5;
    % ===================================

    % === 数据与时间轴提取 ===
    if isa(xx, 'timeseries')
        signals_raw = squeeze(xx.Data);
        t = squeeze(xx.Time); 
        xlabel_default = '时间 (s)';
    elseif isnumeric(xx)
        if ndims(xx) > 2
            signals_raw = squeeze(xx);
        else
            signals_raw = xx;
        end
        [rows, cols] = size(signals_raw);
        numPoints = max(rows, cols);
        t = (1:numPoints)'; 
        xlabel_default = '采样点';
    else
        error('不支持的数据类型，请传入 timeseries 或二维矩阵。');
    end

    % 确定最终坐标轴文本
    if ~isempty(custom_xlabel), xlabel_text = custom_xlabel; else, xlabel_text = xlabel_default; end
    if ~isempty(custom_ylabel), ylabel_text = custom_ylabel; else, ylabel_text = '幅值'; end

    % 统一调整维度：确保 signals 每一行代表一个通道
    [rows, cols] = size(signals_raw);
    if rows < cols
        numSignals = rows;
        signals = signals_raw;
    else
        numSignals = cols;
        signals = signals_raw'; 
    end

    if length(t) ~= size(signals, 2)
        t = (1:size(signals, 2))';
    end

    % --- 处理自定义图例标签 (custom_labels) ---
    labels = cell(1, numSignals);
    if nargin >= 6 && ~isempty(custom_labels)
        for i = 1:numSignals
            if i <= length(custom_labels)
                labels{i} = char(custom_labels(i));
            else
                labels{i} = sprintf('%s_%d', name, i); % 默认下标处理
            end
        end
    else
        % 默认生成方式，带下标格式
        for i = 1:numSignals
            labels{i} = sprintf('%s_%d', name, i);
        end
    end

    % ================= 开始绘图 =================

    % --- 模式 1：叠加显示 ---
    if ismember(1, mode)
        figure('Name', [Fig_title, ' - 叠加显示'], 'Color', 'w');
        p_lines = plot(t, signals', 'LineWidth', line_w);
        set(gca, 'FontSize', fs_axis, 'FontName', font_name, 'LineWidth', 1);
        
        % 修改：Interpreter 改为 'tex' 以支持上下标
        lgd = legend(p_lines, labels, 'Interpreter', 'tex', 'Location', 'best'); 
        set(lgd, 'FontSize', fs_legend, 'FontName', font_name);
        
        title([Fig_title, ' (叠加)'], 'Interpreter', 'tex', 'FontSize', fs_title, 'FontWeight', 'bold', 'FontName', font_name);
        xlabel(xlabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Interpreter', 'tex');
        ylabel(ylabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Rotation', 90, 'Interpreter', 'tex');
        
        xlim([t(1), t(end)]); 
        grid on;
    end

    % --- 模式 2：分栏显示 (Subplots) ---
    if ismember(2, mode)
        figure('Name', [Fig_title, ' - 分栏显示'], 'Color', 'w');
        p = ceil(sqrt(numSignals));
        q = ceil(numSignals/p);

        for i = 1:numSignals
            subplot(p, q, i);
            plot(t, signals(i, :), 'Color', [0.2, 0.4, 0.8], 'LineWidth', line_w); 
            set(gca, 'FontSize', fs_axis, 'FontName', font_name, 'LineWidth', 1);
            
            title(labels{i}, 'Interpreter', 'tex', 'FontSize', fs_title, 'FontWeight', 'bold', 'FontName', font_name);
            xlabel(xlabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Rotation', 90, 'Interpreter', 'tex');
            
            xlim([t(1), t(end)]); 
            grid on;
        end
        sg = sgtitle(Fig_title, 'Interpreter', 'tex'); 
        set(sg, 'FontSize', fs_sgtitle, 'FontWeight', 'bold', 'FontName', font_name);
    end

    % --- 模式 3：单独输出 ---
    if ismember(3, mode)
        for i = 1:numSignals
            figure('Name', sprintf('%s - %s', Fig_title, labels{i}), 'Color', 'w');
            plot(t, signals(i, :), 'Color', [0.8, 0.3, 0.2], 'LineWidth', line_w); 
            set(gca, 'FontSize', fs_axis, 'FontName', font_name, 'LineWidth', 1);
            
            title(sprintf('%s : %s', Fig_title, labels{i}), 'Interpreter', 'tex', 'FontSize', fs_title, 'FontWeight', 'bold', 'FontName', font_name);
            xlabel(xlabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'FontSize', fs_label, 'FontWeight', 'bold', 'FontName', font_name, 'Rotation', 90, 'Interpreter', 'tex');
            
            xlim([t(1), t(end)]); 
            grid on;
        end
    end
end