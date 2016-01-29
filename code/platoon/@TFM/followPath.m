function [u1, u] = followPath(obj, veh, linpath, v, LQR)
% function [u1, u] = followPath(obj, tsteps, hw, v)
%
% Computes the next control input to follow the path rpath
%
% Inputs: obj     - vehicle object
%         tsteps  - number of time steps to look ahead (time horizon is
%                  tsteps*obj.dt)
%         linpath - path to follow
%         v       - speed on the path
%         LQROn   - specify whether to use the LQR controller; if false, an
%                   MPC controller (slower) is used instead
%
% Outputs: u1 - first control action from optimization (only use this for
%               MPC)
%          u  - entire control function from optimization
%
% Mo Chen, 2015-05-23
% Modified: Mo Chen, 2015-11-12
% Modified: Mahesh Vashishtha, 2016-01-28

% Find closest point on the path to current position
s0 = firstPathPoint(veh, linpath.fn);

% Default speed
if nargin < 4
  v = linpath.speed;
end

% Use LQR controller by default
if nargin < 5
  LQR = 1;
end

% Reference velocity
if numel(v) == 1  % Convert to velocity along the highway if needed
  vref = v * linpath.ds;
else
  vref = v;
end

if LQR
  % ----- BEGIN LQR ---
  K = lqr(Quadrotor.A, Quadrotor.B, diag([1 2 1 2]), eye(2)*.01);
  sref = s0;
  rref = linpath.fn(sref);
  u1 = -K* (veh.x - [rref(1); vref(1); rref(2); vref(2)]);
  
  switch class(veh)
    case 'Quadrotor'   
      % Acceleration limit
        if any(u1 > veh.uMax)
          u1 = u1 / max(u1) * veh.uMax;
        end

        if any(u1 < veh.uMin)
          u1 = u1 / min(u1) * veh.uMin;
        end
    case 'Plane4'
      uMax = 3 / sqrt(2);
      uMin = -3 / sqrt(2);
      if any(u1 > uMax)
        u1 = u1 / max(u1) * uMax;
      end

      if any(u1 < uMin)
        u1 = u1 / min(u1) * uMin;
      end
      xi3 = veh.x(3);
      xi4 = veh.x(4);
      M = [cos(xi3) sin(xi3); -sin(xi3) / xi4 cos(xi3) / xi4];
      u1 = M  * u1;
    otherwise 
      error('This has not been implemented yet.')         
  end
  return
end
% ----- END LQR -----

error(['MPC Controller doesn''t work properly! ' ...
  'Try testing it using followPath_test.m'])
tsteps = 5; % MPC time horizon
dt = 0.1; % time step size
% ----- BEGIN CVX -----
cvx_begin
variable p(2, tsteps)     % sequence of vehicle positions
variable v(2, tsteps)     % sequence of vehicle velocities
variable r(2, tsteps)     % sequence of reference positions
variable s(1, tsteps)       % sequence of reference path indices
variable ds(1,tsteps-1)     % sequence of speeds along the path
variable u(obj.nu, tsteps)  % sequence of controls
variable x(obj.nx, tsteps)  % sequence of states

minimize sum(sum((r-p).^2)) + 5*sum(1-s) + sum(sum( (v(1,:)-vref(1)).^2 + (v(2,:)-vref(2)).^2 ))

subject to
% First time step
x(:,1) == veh.dynamics(0, veh.x, u(:,1))*dt   % Dynamics
p(:,1) == x(veh.pdim,1)                        % Position components
v(:,1) == x(veh.vdim,1)
s(1) == s0

%             All time steps afterwards
for i = 2:tsteps
  x(:,i) == veh.dynamics(0, x(:,i-1), u(:,i))*dt        % Dynamics
  p(:,i) == x(veh.pdim,i)                                % Position components
  v(:,i) == x(veh.vdim,i)                                % Position components
  s(i) == s(i-1) + ds(i-1)                            % Advanced on path
end

r == linpath.fn(s)
veh.uMin <= u <= veh.uMax              % Control bounds
% obj.vMin <= v <= obj.vMax                 % Velocity bounds
0 <= s <= 1
ds >= 0

cvx_end
% ----- END CVX -----
if any(isnan(u(:))), keyboard; end  %MPC just takes the first control
u1 = u(:,1);

end % end function


function s0 = firstPathPoint(veh, rpath)
% function s0 = firstPathPoint(rpath, x)
%
% Computes the parameter s0 on rpath that is closest to the current
% position
%
% Inputs:  obj   - current quadrotor object
%          rpath - a straight line path
%
% Output:  s0    - path parameter: rpath(s0) gives the position closest to
%                  obj.x(p.dim)
%
% Mo Chen, 2015-05-23

p = veh.getPosition;

N = 1000;
s = linspace(0,1,N);
rpathd = rpath(s);

[~, ipath] = min((rpathd(1,:)-p(1)).^2 + (rpathd(2,:)-p(2)).^2);
s0 = s(ipath);
% if p(2) >= 3, keyboard; end
end