/*
 * The Onion Browser
 * Copyright (c) 2015-2016 Jean-Romain Garnier
 *
 * See credits.html for redistribution terms.
 */


function __TheOnionBrowerGetHTMLElementsAtPoint(x,y) {
    // Gets all tags linked to the element the user clicked
    var tags = "";
    var e = document.elementFromPoint(x,y);
    while (e) {
        if (e.tagName) {
            tags += e.tagName + ",";
        }
        e = e.parentNode;
    }
    return tags;
}

function __TheOnionBrowerDataAtPoint(x, y) {
    var e = document.elementFromPoint(x,y), tag = "", link = "";
    
    while (e) {
        if (e.tagName) {
            if (e.tagName.toUpperCase() == "A") {
                // Use "" + e to make sure the variables are strings
                tag = "" + e.tagName.toUpperCase();
                link = "" + e;
                break;
            }
            
            if (e.tagName.toUpperCase() == "IMG") {
                tag = "" + e.tagName.toUpperCase();
                link = "" + e.src;
                break;
            }
        }
        
        e = e.parentNode;
    }
    
    if (tag != "A" && tag != "IMG") {
        return ["", ""];
    }
    
    return [tag, link];
}

function __TheOnionBrowerGetLinkInfoAtPoint(x,y) {
    var tag = "", link = "", jsonData = [], fuzz = 40;
    var initialX = x;
    var initialY = y;
    
    // Try to get link/image at different points, by changing y by 5 points each time
    while (Math.abs(y - initialY) <= fuzz && tag == "" && link == "") {
        var data = __TheOnionBrowerDataAtPoint(x, y);
        tag = data[0];
        link = data[1];
        
        if (y <= initialY) {
            y += 5 + 2 * Math.abs(y - initialY);
        } else {
            y -= 5 + 2 * Math.abs(y - initialY);
        }
    }
    
    x = initialX;
    y = initialY;
    
    // Same, but changing x this time
    while (Math.abs(x - initialX) <= fuzz && tag == "" && link == "") {
        var data = __TheOnionBrowerDataAtPoint(x, y);
        tag = data[0];
        link = data[1];
        
        if (x <= initialX) {
            x += 5 + 2 * Math.abs(x - initialX);
        } else {
            x -= 5 + 2 * Math.abs(x - initialX);
        }
    }
    
    jsonData.push(link);
    jsonData.push(tag);
        
    return JSON.stringify(jsonData);
}
