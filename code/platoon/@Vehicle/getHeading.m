function [h, hhist] = getHeading(obj)
% heading = getHeading(obj)
%     returns the heading and optionally heading history of the vehicle

if length(obj.vdim) <= 1
  h = 1;
  hhist = ones(1, size(obj.x, 2));
  return
end

% If heading is a state
if ~isempty(obj.hdim)
  h = obj.x(obj.hdim);
  hhist = obj.xhist(obj.hdim, :);
  return
end

% If vehicle has at least 2 velocity dimensions
[v, vhist] = obj.getVelocity;
h = atan2(v(2), v(1));
hhist = atan2(vhist(2,:), vhist(1,:));
end