function __TheOnionBrowerGetHTMLElementsAtPoint(x,y) {
    var tags = "";
    var e = document.elementFromPoint(x,y);
    while (e) {
        if (e.tagName) {
            tags += e.tagName + ',';
        }
        e = e.parentNode;
    }
    return tags;
}

function __TheOnionBrowerGetLinkInfoAtPoint(x,y) {
    var e = document.elementFromPoint(x,y);
    var tag;
    var name;
    var link;
    var jsonData = [];
    
    while (e) {
        if (e.tagName.toUpperCase() == "A") {
            name = "" + e.text;
            tag = "" + e.tagName.toUpperCase();
            link = "" + e;
            break;
        }
        
        if (e.tagName.toUpperCase() == "IMG") {
            name = "" + e.getAttribute("alt");
            tag = "" + e.tagName.toUpperCase();
            link = "" + e.src;
            break;
        }

        e = e.parentNode;
    }
    
    jsonData.push(link)
    jsonData.push(tag)
    jsonData.push(name)

    return JSON.stringify(jsonData);
}
