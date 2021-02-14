/**
 * Rendering the Table of Contents / Navigation Bar
 * To use insert some element with `id="toc"`
 * This will then scan and insert links for any heading of level 2 or 3
 * Will insert an ID if one is not present
**/
window.onload = function () {
    function extractStructure() {
        var headingsNodes = document.querySelectorAll("h2, h3");
        // For now we are just fulling going to regenerate the structure each time
        // Might be better if we made minimal changes, but 🤷

        // Extract the structure of the document
        var structure = {children:[]}
        var active = [structure.children];
        headingsNodes.forEach(
            function(currentValue, currentIndex) {
                if (currentValue.id == null) {
                    currentValue.id = "s-" + currentIndex;                
                }

                // Subtract 1 as we are skipping `h1`
                var currentLevel = parseInt(currentValue.nodeName[1]) - 1;

                // Insert dummy levels up for any levels that are skipped
                for (var i=active.length; i < currentLevel; i++) {
                    var dummy = {id: "", text: "", children: []}
                    active.push(dummy.children);
                    var parentList = active[i-1]
                    parentList.push(dummy);
                }
                // delete this level and everything after
                active.splice(currentLevel, active.length);

                var currentStructure = {
                    id: currentValue.id,
                    text: currentValue.textContent,
                    children: [],
                };
                active.push(currentStructure.children);

                var parentList = active[active.length-2]
                parentList.push(currentStructure);
            },
        );
        return structure;
    }


    function navItemList(struct) {
        var listEle = document.createElement('ol')
        struct.children.forEach(childStruct=>
            listEle.appendChild(navItem(childStruct))
        );
        return listEle;
    }
    function navItem(struct) {
        var a = document.createElement('a');
        a.appendChild(document.createTextNode(struct.text));
        a.title = struct.text;
        a.href = "#"+struct.id;

        var ele = document.createElement('li')
        ele.appendChild(a)
        ele.appendChild(navItemList(struct));
        return ele;
    }

    //////////////////////////////////////////////
    // Run it.
    var navbarEle = document.getElementById("toc")
    if (navbarEle == null) {
        // Exit if not present
        return;
    }

    var structure = extractStructure()
    navbarEle.appendChild(navItemList(structure));
}; // window.onload