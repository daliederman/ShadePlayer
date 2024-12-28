# shade_player

Shade Media Player is intended as a lightweight and multiplatform app for casual library playback featuring tools for curation of a main shuffle selection and a variety of smart playlists.

Video demo: TBD

Goals:
	- Primary, MVP: Support playback of a library of music files with specific tracks included or excluded from shuffle
		- Keep an index of media files, flexibly support importing, exporting, and handling missing entries
Stretch goals:
	- Allow smart selection of tracks with common musical components
		- eg. tempo, genre, sentiment, rating
		- Fetch data from a 3rd party API if at all possible
	- Automate playlist with broader themes using the data above
		- eg. escalation of energy (tempo in genre), 3-act (loose) "story", back-and-forth
Potential goals:
	- With user consent, network with other instances with the same tracks and anonymously recommend playlists from others' music preferences
	- Recommend tracks a user might be interested in based on the above data

Early devlog: 
2024-12-27 We're back after a full laptop replacement, starting from scratch once more! This project's written in Flutter; I'm jumping in just after completing the codelab example. Based on the UI-emphasizing language, the simplicity widgets provide for the scope of the project, and the available libraries, Flutter should be a great fit for the project. My main effort will be focused on building the library index file, with which to store media metadata and paths, other than that the app should be running swiftly. 

The UI code is straightforward enough, so it's living in main.dart. In the future it would make sense to split out settings, additional feature, and detailed media control, but for this minimum viable production the code need not be spread out to more files than it can meaningfully fill. 

The media library code however does get separate handling - it is substantial enough to warrant good organization.