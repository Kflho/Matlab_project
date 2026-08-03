function run_visualization(figh)
% 应用论文统一图形格式。若未传入图窗句柄，默认对 gcf 操作。
    if nargin < 1 || isempty(figh)
        figh = gcf;
    end
    % 保护：无效句柄直接返回
    if ~ishandle(figh) || ~isvalid(figh)
        return;
    end
    figure(figh);   % 确保其为当前图窗

    % 检查坐标轴
    if isempty(get(figh, 'CurrentAxes'))
        return;
    end

    % 依次应用设置
    fig_setting;               % 白色背景（内部使用 gcf，因已 figure(figh) 故安全）
    axes_setting_2d;
    label_setting_2d;

    hLeg = findobj(figh, 'Type', 'Legend');
    if ~isempty(hLeg)
        legend_setting;
    end

    hTitle = get(figh, 'CurrentAxes');
    if ~isempty(hTitle) && ~isempty(get(hTitle, 'Title'))
        title_setting;
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