const XUL_NS = "http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul";
var dbCon;

var rowsadded;

var gBundle = Components.classes["@mozilla.org/intl/stringbundle;1"].getService(Components.interfaces.nsIStringBundleService);
var words = gBundle.createBundle("chrome://koct/locale/koct.properties");

function onReady() {
    rowsadded = 0;

    restorePreferences();

    var file = Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("ProfD", Components.interfaces.nsIFile);
    file.append("offlinecirc.sqlite");

    var storageService = Components.classes["@mozilla.org/storage/service;1"]
        .getService(Components.interfaces.mozIStorageService);
    dbConn = storageService.openDatabase(file);

    dbConn.executeSimpleSQL("CREATE TABLE IF NOT EXISTS offlinecirc (timestamp TIMESTAMP, action VARCHAR, cardnumber VARCHAR, barcode VARCHAR, status VARCHAR)");

    var statement = Components.classes['@mozilla.org/storage/statement-wrapper;1'].createInstance(Components.interfaces.mozIStorageStatementWrapper);
    var query = dbConn.createStatement("SELECT COUNT(*) AS numrow FROM offlinecirc");
    statement.initialize(query);
    statement.step();
    if(statement.row.numrow) {
        var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"].getService(Components.interfaces.nsIPromptService);
        var deleteRows = {value: null};
        if(prompts.confirmCheck(window, words.GetStringFromName("warning"), words.GetStringFromName("confirm_delete1")+" "+statement.row.numrow+" " + words.GetStringFromName("confirm_delete2"), words.GetStringFromName("i_want_to_delete"), deleteRows)){
            if (deleteRows.value){
                dbConn.executeSimpleSQL("DELETE FROM offlinecirc");
            }
        }
    }
}

function updateTree() {
    var treechildren = document.getElementById("treechildren");
    while (treechildren.firstChild) {
        treechildren.removeChild(treechildren.firstChild);
    }

    var statement = Components.classes['@mozilla.org/storage/statement-wrapper;1'].createInstance(Components.interfaces.mozIStorageStatementWrapper);
    var query = dbConn.createStatement("SELECT * FROM offlinecirc");
    statement.initialize(query);
    while (statement.step()) {
        var treeitem = document.createElementNS(XUL_NS, "treeitem");

        var treerow = document.createElementNS(XUL_NS, "treerow");
        treeitem.appendChild(treerow);

        var treecell = document.createElementNS(XUL_NS, "treecell");
        treecell.setAttribute("label", statement.row.timestamp);
        treerow.appendChild(treecell);

        if (statement.row.action=='issue'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('checkout'));
        }
        else {
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('checkin'));
        }
        treerow.appendChild(treecell);

        treecell = document.createElementNS(XUL_NS, "treecell");
        treecell.setAttribute("label", statement.row.cardnumber);
        treerow.appendChild(treecell);

        treecell = document.createElementNS(XUL_NS, "treecell");
        treecell.setAttribute("label", statement.row.barcode);
        treerow.appendChild(treecell);

        if (statement.row.status=='Success.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('success'));
        }
        else if (statement.row.status=='Added.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('added'));
        }
        else if (statement.row.status=='Authentication failed.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('auth_failed'));
        }
        else if (statement.row.status=='Borrower not found.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('cardnumber_wrong'));
        }
        else if (statement.row.status=='Item not found.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('item_not_found'));
        }
        else if (statement.row.status=='Item not issued.'){
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", words.GetStringFromName('item_not_issued'));
        }
        else {
            treecell = document.createElementNS(XUL_NS, "treecell");
            treecell.setAttribute("label", statement.row.status);
        }
        treerow.appendChild(treecell);

        treechildren.appendChild(treeitem);
    }
}

function save(attr) {
    switch(attr) {
        case 'issue':
            var patronbarcode = document.getElementById('issuepatronbarcode').value;
            var itembarcode = document.getElementById('issueitembarcode').value;
            dbConn.executeSimpleSQL("INSERT INTO offlinecirc VALUES(CURRENT_TIMESTAMP,'issue','"+patronbarcode+"','"+itembarcode+"','Local.')");
            rowsadded++;
            document.getElementById('issuepatronbarcode').value = '';
            document.getElementById('issueitembarcode').value = '';
            document.getElementById('issuepatronbarcode').focus();
            document.getElementById('status').setAttribute("label",rowsadded+" "+words.GetStringFromName('records_added'));
            break;
        case 'return':
            var itembarcode = document.getElementById('returnitembarcode').value;
            dbConn.executeSimpleSQL("INSERT INTO offlinecirc VALUES(CURRENT_TIMESTAMP,'return',NULL,'"+itembarcode+"','Local.')");
            rowsadded++;
            document.getElementById('returnitembarcode').value = '';
            document.getElementById('returnitembarcode').focus();
            document.getElementById('status').setAttribute("label",rowsadded+" "+words.GetStringFromName('records_added'));
            break;
    }
}

function checkReturn(e, nextFieldName, attr) {
    var event;
    var key
    var cChar
    var retCheck = /\r/;

    if (window.event) {
        event = window.event;
        key = window.event.keyCode;
        target = event.srcElement;
    } else if (e) {
        event = e;
        key = event.which;
        target = event.target;
    }

    cChar= String.fromCharCode(key)

    if(retCheck.test(cChar)) {
        document.getElementById(nextFieldName).focus();
        if(attr) {
            save(attr);
        }
    }
}

function restorePreferences() {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefService);
    prefs = prefs.getBranch("extensions.koct.");

    for each( pref in ['server','branchcode','username','password'] ) {
        document.getElementById(pref).value = prefs.getComplexValue("preference."+pref,
            Components.interfaces.nsISupportsString).data;
    }
}

function savePreferences() {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefService);
    prefs = prefs.getBranch("extensions.koct.");
    var str = Components.classes["@mozilla.org/supports-string;1"]
        .createInstance(Components.interfaces.nsISupportsString);

    for each( pref in ['server','branchcode','username','password'] ) {
        str.data = document.getElementById(pref).value;
        prefs.setComplexValue("preference."+pref,
            Components.interfaces.nsISupportsString, str);
    }
}

function commit( pending ) {
    var statement = Components.classes['@mozilla.org/storage/statement-wrapper;1'].createInstance(Components.interfaces.mozIStorageStatementWrapper);
    var query = dbConn.createStatement("SELECT * FROM offlinecirc WHERE status='Local.' OR status='Authentication failed.'");
    statement.initialize(query);

    var url = document.getElementById('server').value+"/cgi-bin/koha/offline_circ/service.pl";

    while ( statement.step() ) {

        var params = "userid="      + document.getElementById('username').value;
        params    += "&password="   + document.getElementById('password').value;
        params    += "&branchcode=" + document.getElementById('branchcode').value;
        params    += "&pending="    + pending;
        params    += "&action="     + statement.row.action;
        params    += "&timestamp="  + statement.row.timestamp;
        params    += statement.row.cardnumber ? "&cardnumber=" + statement.row.cardnumber : "";
        params    += "&barcode="    + statement.row.barcode;

        var req = new XMLHttpRequest();
        req.open("POST", url, false);
        req.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
        req.setRequestHeader("Content-length", params.length);
        //req.setRequestHeader("Connection", "close");
        req.send(params);

        if ( req.status == 200 ) {
            dbConn.executeSimpleSQL("UPDATE offlinecirc SET status='"+req.responseText+"' WHERE timestamp='"+statement.row.timestamp+"'");
            updateTree();
        }
    }
}

function clear() {
    var statement = Components.classes['@mozilla.org/storage/statement-wrapper;1'].createInstance(Components.interfaces.mozIStorageStatementWrapper);
    var query = dbConn.createStatement("SELECT * FROM offlinecirc");
    statement.initialize(query);

    dbConn.executeSimpleSQL("DELETE FROM offlinecirc");
    updateTree();
}
