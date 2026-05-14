function Plot_signals_v5(xx, name, Fig_title, mode, axis_labels, custom_labels)
    % 功能：自动识别维度，提取时间轴，支持自定义坐标轴标签及图例名称（LaTeX 渲染）
    % 注意：本函数会在绘图完成后自动调用格式脚本（Visualization/ 下），无需外部重复设置。
    % 参数：
    %   xx            : 数据 (timeseries 或 矩阵)
    %   name          : 默认信号名前缀 (如 'r' 则生成 r1, r2...)
    %   Fig_title     : 图像标题
    %   mode          : 模式 (1:叠加, 2:分栏, 3:单独)
    %   axis_labels   : 坐标轴标签 {'X轴字符串', 'Y轴字符串'}
    %   custom_labels : 自定义图例/信号名称 (字符串数组，无需自行加 $)

    % 1. 输入参数处理
    if nargin < 2 || isempty(name), name = 'xx'; end
    if nargin < 3 || isempty(Fig_title), Fig_title = name; end
    if nargin < 4 || isempty(mode), mode = 1; end

    custom_xlabel = '';
    custom_ylabel = '';
    if nargin >= 5 && iscell(axis_labels) && length(axis_labels) >= 2
        custom_xlabel = axis_labels{1};
        custom_ylabel = axis_labels{2};
    end

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

    if ~isempty(custom_xlabel), xlabel_text = custom_xlabel; else, xlabel_text = xlabel_default; end
    if ~isempty(custom_ylabel), ylabel_text = custom_ylabel; else, ylabel_text = '幅值'; end

    % 统一调整维度：signals 每一行为一个信号
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

    % --- 处理图例标签：自动包裹为合法 LaTeX 数学模式 ---
    labels = cell(1, numSignals);
    if nargin >= 6 && ~isempty(custom_labels)
        for i = 1:numSignals
            if i <= length(custom_labels)
                labels{i} = char(custom_labels(i));
            else
                labels{i} = sprintf('%s_%d', name, i);
            end
        end
    else
        for i = 1:numSignals
            labels{i} = sprintf('%s_%d', name, i);
        end
    end
    % 将标签转换为 LaTeX 数学模式字符串（若非空且不含 $，则加 $...$）
    latex_labels = cellfun(@(s) ensure_latex(s), labels, 'UniformOutput', false);

    % ================= 绘图核心（自动集成格式） =================

    % --- 模式 1：叠加显示 ---
    if ismember(1, mode)
        figure('Name', Fig_title, 'Color', 'w');
        fig_setting;   % 图窗背景与尺寸
        % 逐条绘制，并设置 DisplayName（供后续 Add_Threshold 重建图例）
        for i = 1:numSignals
            plot(t, signals(i,:), 'DisplayName', latex_labels{i});
            hold on;
        end
        hold off;
        legend('Interpreter', 'latex', 'Location', 'best');
        title(Fig_title, 'Interpreter', 'tex');
        xlabel(xlabel_text, 'Interpreter', 'tex');
        ylabel(ylabel_text, 'Interpreter', 'tex', 'Rotation', 90);
        xlim([t(1), t(end)]);
        grid on;
        % 应用统一格式
        axes_setting_2d;
        label_setting_2d;
        legend_setting;
        title_setting;
    end

    % --- 模式 2：分栏显示 ---
    if ismember(2, mode)
        figure('Name', Fig_title, 'Color', 'w');
        fig_setting;
        p = ceil(sqrt(numSignals));
        q = ceil(numSignals / p);
        for i = 1:numSignals
            subplot(p, q, i);
            plot(t, signals(i,:), 'Color', [0.2, 0.4, 0.8], ...
                'DisplayName', latex_labels{i});
            title(latex_labels{i}, 'Interpreter', 'latex');
            xlabel(xlabel_text, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'Interpreter', 'tex', 'Rotation', 90);
            xlim([t(1), t(end)]);
            grid on;
            % 对每个子图应用格式
            axes_setting_2d;
            label_setting_2d;
            title_setting;
        end
        sg = sgtitle(Fig_title, 'Interpreter', 'tex');
    end

    % --- 模式 3：单独输出 ---
    if ismember(3, mode)
        for i = 1:numSignals
            figure('Name', sprintf('%s - %s', Fig_title, labels{i}), 'Color', 'w');
            fig_setting;
            plot(t, signals(i,:), 'Color', [0.8, 0.3, 0.2], ...
                'DisplayName', latex_labels{i});
            title(sprintf('%s : %s', Fig_title, labels{i}), 'Interpreter', 'tex');
            xlabel(xlabel_text, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'Interpreter', 'tex', 'Rotation', 90);
            xlim([t(1), t(end)]);
            grid on;
            % 应用统一格式
            axes_setting_2d;
            label_setting_2d;
            title_setting;
            legend_setting;   % 若无图例，此脚本不会报错
        end
    end
end

% ============= 局部辅助函数 =============
function str_out = ensure_latex(str_in)
    % 将普通字符串转为合法的 LaTeX 数学模式字符串
    if ~ischar(str_in)
        str_out = str_in;
        return;
    end
    % 若已包含 $，说明用户已手动添加，不再包裹
    if contains(str_in, '$')
        str_out = str_in;
    else
        str_out = ['$', str_in, '$'];
    end
end