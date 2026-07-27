function add_threshold(threshold_value, threshold_label, ax)
    % 功能：添加阈值虚线并更新图例（自动适配 LaTeX 标签）
    % 注意：不设置字体、线宽等样式，全部交由外部脚本控制。
    % 参数：
    %   threshold_value : 阈值数值
    %   threshold_label : 阈值标签（支持 LaTeX，无需自行添加 $）
    %   ax              : (可选) 目标坐标轴句柄，默认 gca

    if nargin < 3 || isempty(ax)
        ax = gca;
    end

    if nargin < 2 || isempty(threshold_label)
        threshold_label = 'Threshold';
    end

    % 获取当前图窗
    fig = ancestor(ax, 'figure');
    % 临时激活目标图窗和坐标轴，使后续格式设置脚本能正确找到它们
    if ishandle(fig) && isvalid(fig)
        set(0, 'CurrentFigure', fig);
        set(fig, 'CurrentAxes', ax);
    end

    % 将标签转为合法 LaTeX 字符串（若无 $ 则包裹）
    latex_th_label = ensure_latex(threshold_label);

    all_axes = ax;  % 原代码遍历所有轴，此处改为仅处理传入的轴
    for i = 1:length(all_axes)
        ax_curr = all_axes(i);
        % 排除图例、颜色条
        if ~isempty(ax_curr.Tag) && (contains(ax_curr.Tag, 'Legend') || contains(ax_curr.Tag, 'Colorbar'))
            continue;
        end

        hold(ax_curr, 'on');
        existing_th = findobj(ax_curr, 'Tag', 'ThresholdLine');
        if ~isempty(existing_th), delete(existing_th); end

        % 绘制阈值线，并设置 DisplayName
        h_th = yline(ax_curr, threshold_value, '--r', ...
            'Tag', 'ThresholdLine', 'DisplayName', latex_th_label);

        % 重建图例（简单方式，信任所有对象的 DisplayName 已正确）
        all_lines = findobj(ax_curr, 'Type', 'line', '-or', 'Type', 'constantline');
        if isempty(all_lines), continue; end
        % 只保留 Visible 且 Annotation 允许的线条
        valid_lines = [];
        for k = 1:length(all_lines)
            if strcmp(all_lines(k).Visible, 'on') && ...
               strcmp(get(all_lines(k).Annotation).LegendInformation.IconDisplayStyle, 'on')
                valid_lines = [valid_lines; all_lines(k)]; %#ok<AGROW>
            end
        end
        if isempty(valid_lines), continue; end

        % 获取当前图例位置（若存在）
        old_lgd = findobj(fig, 'Type', 'Legend', 'Axes', ax_curr);  % 修复为从当前图窗寻找
        if ~isempty(old_lgd)
            old_loc = old_lgd.Location;
            delete(old_lgd);
        else
            old_loc = 'best';
        end

        % 重建图例，不指定标签字符串，完全依靠 DisplayName
        new_lgd = legend(ax_curr, valid_lines, 'Location', old_loc);
        set(new_lgd, 'Interpreter', 'latex');    % 使用 LaTeX 解释器（后续 legend_setting 会再次统一）
        drawnow;
        % 重建图例后调用 legend_setting（当前图窗和坐标轴已激活）
        if ~isempty(new_lgd)
            legend_setting;
        end
    end
end

function str_out = ensure_latex(str_in)
    if ~ischar(str_in), str_out = str_in; return; end
    if contains(str_in, '$')
        str_out = str_in;
    else
        str_out = ['$', str_in, '$'];
    end
end