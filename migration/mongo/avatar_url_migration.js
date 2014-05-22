// migration script to change avatarUrl and groupAvatarUrl fields
// to match the new filecache URI
//
// usage: mongo talk avatar_url_migration.js

var regex = /^((https|http):\/\/.*?hoccer\.(de|com))(\/.*)$/;
var port_str = ":8444";

// avatarUrl (in 'presence' collection)
var dbq_results = db.presence.find( {"avatarUrl": regex} );
print("migrating " + dbq_results.count() + " document(s) in 'presence' collection...");
dbq_results.forEach(
	function(doc) {
		print('  old: ' + doc.avatarUrl);
		var newUrl = doc.avatarUrl.replace(regex, '$1' + port_str + '$4');
		doc.avatarUrl = newUrl;
		print('  new: ' + doc.avatarUrl + '\n');
		db.presence.save(doc);
	}
);
print("Done.");

// groupAvatarUrl (in 'group' collection)
dbq_results = db.getCollection("group").find( {"groupAvatarUrl": regex} );
print("migrating " + dbq_results.count() + " document(s) in 'group' collection...");
dbq_results.forEach(
	function(doc) {
		print('  old: ' + doc.groupAvatarUrl);
		var newUrl = doc.groupAvatarUrl.replace(regex, '$1' + port_str + '$4');
		doc.groupAvatarUrl = newUrl;
		print('  new: ' + doc.groupAvatarUrl + '\n');
		db.getCollection("group").save(doc);
	}
);
print("Done.");
