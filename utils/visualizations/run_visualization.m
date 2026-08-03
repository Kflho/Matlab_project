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