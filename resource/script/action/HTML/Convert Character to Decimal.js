var isExist = ClipMenu.require('JS-methods/char');
if (!isExist) {
    throw new Error('Cound not find the library');
}

return clipText.char2dec();

