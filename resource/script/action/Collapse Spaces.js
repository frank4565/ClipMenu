var isExist = ClipMenu.require('JS-methods/string');
if (!isExist) {
    throw new Error('Cound not find the library');
}

return clipText.collapseSpaces();

