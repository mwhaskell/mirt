function [wmap, wconv] = fmap_est_qm_wrapper(yik, etime, varargin)
% This function is a wrapper for fmap_est_qm.m to make it callable in a
% similar fashion as mri_field_map_reg.m

%|	yik	[(N) nset ncoil]	complex images at different echo times
%|				(these should be undistorted)
%|				(N) can be (nx,ny) or (nx,ny,nz) etc.
%|	etime	[nset]		vector of echo times [usually in seconds]
%|
%| options
%|	l2b		log_2(beta), regularization parameter (default: -3)
%|	order		regularization order (default: 2)
%|	niter		# of iterations (default: 40)
%|	fmax		percent of median used in calculating scale factor (.1)
%| 	wthresh		percent of median used in masking out for RMSerror (.1)
%|	winit	[(N)]		initial field map for iterating
%|				(default: estimate from first two scans)
%|	mask	[(N)]		logical support mask (only estimate within this)
%|  sens    [(N) ncoil] sensitivity maps
%|  quiet       supresses all output from function
%|
%| out
%|	wmap	[(N)]	regularized estimate of field map [rad/sec]
%|	wconv	""	conventional estimate from first two scans

% default optional arguments set here! If there are changes in
% fmap_est_qm.m defaults they need to be changed here as well
arg.niter = 30;
arg.maskR = [];
arg.order = 2;
arg.l2b = -6;
arg.hess = 'diag';
arg.dim = 3; % diag curvature for 2d / 3d
arg.df = 0;
arg.relamp = 1;
arg.quiet = false;
arg.winit = [];
arg.sens = [];
arg = vararg_pair(arg, varargin);


% determine data size & reshape as needed
if numel(size(yik)) == 3 
    % 2d single coil
    [nlin, ncol, necho] = size(yik); size_v = [nlin, ncol];
    y = reshape(yik,[nlin*ncol,1,necho]);
    arg.sens = ones(nlin*ncol,1);
elseif numel(size(yik)) == 4
    if isempty(arg.sens)
        % 3d single coil
        [nlin, ncol, nsli, necho] = size(yik); size_v = [nlin, ncol, nsli];
        y = reshape(yik,[nlin*ncol*nsli,1,necho]);
        arg.sens = ones(nlin*ncol*nsli,1);
    else
        % 2d multicoil
        [nlin, ncol, necho, ncoil] = size(yik); size_v = [nlin, ncol];
        y = reshape(permute(yik,[1 2 4 3]),[nlin*ncol,ncoil,necho]);
    end
else
    % 3d multicoil
    [nlin, ncol, nsli, necho, ncoil] = size(yik); size_v = [nlin, ncol, nsli];
    y = reshape(permute(yik,[1 2 3 5 4]),[nlin*ncol*nsli,ncoil,necho]);
end

% initialize mask
if isempty(arg.maskR)
    if ~exist('nsli','var')
        arg.maskR = true(nlin,ncol);
    else
        arg.maskR = true(nlin,ncol,sli);
    end
end

% conventional field map estimate from first two scans
wconv = angle(stackpick(yik,2) .* conj(stackpick(yik,1))) ...
	/ (etime(2) - etime(1));

if isempty(arg.winit), arg.winit = wconv; end
w = arg.winit(:);

%%%%%  call fmap_est_qm
func_name = 'fmap_est_qm';

% prep optional arguments to be passed into fmap function
arg_fmap = arg;
arg_fmap = rmfield(arg_fmap,'sens');   % remove sensitivity maps, since it's now an input
arg_fmap = rmfield(arg_fmap,'winit');  % remove image initialization, since it's now an input
arg_fmap = rmfield(arg_fmap,'quiet');  % remove option only used in this function
varargin_fmap = arg2varargin(arg_fmap);

% call function
command = strcat("wmap_structure = ",func_name,"(w, y, etime, arg.sens, varargin_fmap{:});");
if arg.quiet
    evalc(command);
else
    eval(command)
end
wmap = reshape(wmap_structure.ws(:,end),size_v);
end
