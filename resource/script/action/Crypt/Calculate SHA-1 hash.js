var isExist = ClipMenu.require('v8cgi/util');
if (!isExist) {
    throw new Error('Cound not find the library');
}

return Util.sha1(clipText);

