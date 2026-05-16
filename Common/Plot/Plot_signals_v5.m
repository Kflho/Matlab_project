function varargout = Plot_signals_v5(xx, name, Fig_title, mode, axis_labels, custom_labels)
% 功能：绘制信号曲线，不设置任何字体、线宽、背景样式。
%       所有外观格式请用 Run_visualization 统一处理。
%
% 参数：
%   xx            : 数据 (timeseries 或 矩阵)
%   name          : 默认信号名前缀
%   Fig_title     : 图像标题
%   mode          : 1-叠加, 2-分栏, 3-单独
%   axis_labels   : 坐标轴标签 {'X','Y'}
%   custom_labels : 自定义图例名称字符串数组

    if nargin < 2 || isempty(name), name = 'xx'; end
    if nargin < 3 || isempty(Fig_title), Fig_title = name; end
    if nargin < 4 || isempty(mode), mode = 1; end

    custom_xlabel = ''; custom_ylabel = '';
    if nargin >= 5 && iscell(axis_labels) && length(axis_labels) >= 2
        custom_xlabel = axis_labels{1};
        custom_ylabel = axis_labels{2};
    end

    % ---- 数据提取 ----
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
        error('不支持的数据类型。');
    end

    if ~isempty(custom_xlabel), xlabel_text = custom_xlabel; else, xlabel_text = xlabel_default; end
    if ~isempty(custom_ylabel), ylabel_text = custom_ylabel; else, ylabel_text = '幅值'; end

    % ---- 统一维度 ----
    [rows, cols] = size(signals_raw);
    if rows < cols
        numSignals = rows;
        signals = signals_raw;
    else
        numSignals = cols;
        signals = signals_raw';
    end
    if length(t) ~= size(signals,2)
        t = (1:size(signals,2))';
    end

    % ---- 图例标签 (LaTeX 数学模式包裹) ----
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
    latex_labels = cellfun(@(s) ensure_latex(s), labels, 'UniformOutput', false);

    % ================== 纯绘图 (无任何格式设置) ==================

    if ismember(1, mode)          % 叠加
        hFig = figure('Name', Fig_title);
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
        varargout{1} = hFig;
    end

    if ismember(2, mode)          % 分栏
        hFig = figure('Name', Fig_title);
        p = ceil(sqrt(numSignals));
        q = ceil(numSignals / p);
        for i = 1:numSignals
            subplot(p, q, i);
            plot(t, signals(i,:), 'Color', [0.2,0.4,0.8], 'DisplayName', latex_labels{i});
            title(latex_labels{i}, 'Interpreter', 'latex');
            xlabel(xlabel_text, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'Interpreter', 'tex', 'Rotation', 90);
            xlim([t(1), t(end)]);
            grid on;
        end
        sgtitle(Fig_title, 'Interpreter', 'tex');
        varargout{1} = hFig;
    end

    if ismember(3, mode)          % 单独输出
        hFigs = gobjects(numSignals, 1);
        for i = 1:numSignals
            hFigs(i) = figure('Name', sprintf('%s - %s', Fig_title, labels{i}));
            plot(t, signals(i,:), 'Color', [0.8,0.3,0.2], 'DisplayName', latex_labels{i});
            title(sprintf('%s : %s', Fig_title, labels{i}), 'Interpreter', 'tex');
            xlabel(xlabel_text, 'Interpreter', 'tex');
            ylabel(ylabel_text, 'Interpreter', 'tex', 'Rotation', 90);
            xlim([t(1), t(end)]);
            grid on;
        end
        varargout{1} = hFigs;
    end
end

% ============= 局部辅助函数 =============
function str_out = ensure_latex(str_in)
    if ~ischar(str_in)
        str_out = str_in;
        return;
    end
    if contains(str_in, '$')
        str_out = str_in;
    else
        str_out = ['$', str_in, '$'];
    end
end