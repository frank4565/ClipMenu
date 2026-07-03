var isExist = ClipMenu.require('showdown');
if (!isExist) {
    throw new Error('Cound not find the file');
}

var converter = new Showdown.converter();

return converter.makeHtml(clipText);

