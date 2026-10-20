function run_visualization(figh)
% 应用论文统一图形格式。若未传入图窗句柄，默认对 gcf 操作。
% 支持多 subplot：对图窗内所有数据坐标轴逐一应用格式。
    if nargin < 1 || isempty(figh)
        figh = gcf;
    end
    % 保护：无效句柄直接返回
    if ~ishandle(figh) || ~isvalid(figh)
        return;
    end
    figure(figh);   % 确保其为当前图窗

    % 图窗级设置（白色背景，内部使用 gcf）
    fig_setting;

    % 收集所有数据坐标轴（排除图例内部轴 Tag='legend'）
    hAxAll = findobj(figh, 'Type', 'Axes');
    hAxAll = hAxAll(arrayfun(@(h) ~strcmp(get(h, 'Tag'), 'legend'), hAxAll));
    if isempty(hAxAll)
        return;
    end

    % 逐轴应用二维格式（axes_setting_2d/label_setting_2d/title_setting
    % 内部均使用 gca，故先 axes(hAx) 设为当前轴再调用）
    for i = 1:numel(hAxAll)
        axes(hAxAll(i));
        axes_setting_2d;
        label_setting_2d;
        title_setting;
        % 标题严格单行：超宽标题仅告警不换行，措辞精简由 AI 判断完成
        warn_overlong_title(hAxAll(i));
    end

    % 图例（图窗级，一次处理全部）
    hLeg = findobj(figh, 'Type', 'Legend');
    if ~isempty(hLeg)
        legend_setting;
    end

    % 数据线条 1.5pt，参考线（yline/xline）保持较细
    hDataLines = findobj(figh, 'Type', 'Line');
    if ~isempty(hDataLines)
        set(hDataLines, 'LineWidth', 1.5);
    end
    hRefLines = findobj(figh, 'Type', 'ConstantLine');
    if ~isempty(hRefLines)
        set(hRefLines, 'LineWidth', 1.0);
    end
end

% ---------------------------------------------------------------------
% 局部函数：标题超宽检测（严格一行，不换行）
% 多行标题会纵向溢出图外，因此禁止自动换行。
% 运行日志中出现本函数打印的 [run_visualization] 标题超宽 告警时，
% AI 必须精简对应标题措辞并重跑对应实验，直至无告警。
% ---------------------------------------------------------------------
function warn_overlong_title(hAx)
    MAXW = 48;   % 单栏图一行标题有效宽度上限（CJK 全宽字计 2，ASCII 计 1）
    hTitle = get(hAx, 'Title');
    str = get(hTitle, 'String');
    if isempty(str)
        return;
    end
    if iscell(str)
        str = strjoin(str, ' ');   % 已是多行则合并评估（多行本身即违规）
    end
    str = char(str);
    if eff_width(str) > MAXW
        fprintf('[run_visualization] 标题超宽(%d>%d)，严格一行放不下，需精简措辞: "%s"\n', ...
            eff_width(str), MAXW, str);
    end
end

function w = eff_width(str)
% 有效宽度：非 ASCII（CJK 等全宽字符）计 2，ASCII 计 1
    n = numel(str);
    w = sum(double(str) > 127) * 2 + sum(double(str) <= 127);
end