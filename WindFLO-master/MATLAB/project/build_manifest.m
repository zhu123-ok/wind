function manifest = build_manifest()
% BUILD_MANIFEST 生成源码清单、代码行数和 SHA-256，便于复核版本。
here = fileparts(mfilename('fullpath'));
files = dir(fullfile(here,'*.m'));
items = repmat(struct('file','','lines',0,'sha256',''),length(files),1);
for i = 1:length(files)
    path = fullfile(here,files(i).name);
    text = fileread(path);
    items(i).file = files(i).name;
    items(i).lines = sum(text == newline)+1;
    fid = fopen(path,'rb');
    bytes = fread(fid,inf,'*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    digest = typecast(md.digest(),'uint8');
    items(i).sha256 = lower(reshape(dec2hex(digest,2)',1,[]));
    clear md;
end
manifest = struct('language','MATLAB','entryPoints', ...
    {{'main_compare.m','main_large_scale.m','main_continuous.m', ...
    'test_project.m','test_continuous_project.m'}}, ...
    'files',items);
fid = fopen(fullfile(here,'code_manifest.json'),'w');
fwrite(fid,jsonencode(manifest),'char');
fclose(fid);
end
