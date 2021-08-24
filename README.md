Open GPX Follower
=================

- Load GPX files from Internet or open GPX files from other app on your iOS device and display them on map
- When you start moving, map will 
  - automatically rotate in moving direction
  - and pan the screen as you move
  - zoom in our out accoording to speed
- when going away from the track, the map will zoom in and out, to make sure the track remains visible on the map
- with offline map cache support.
- Supports Apple Map Kit, [Open Street Map](http://wiki.openstreetmap.org/wiki/Tile_usage_policy) and [Carto DB](http://www.cartodb.com) as map sources
 - Offline maps support (of browsed areas)
 - Displays current location and altitude
 - Displays user heading (device orientation) 
 - Share GPX files with other apps
 - Settings
    - Offline cache On/Off
    - Clear cache
    - Select the map server.
  - Darkmode
 
Based on [GPX Tracker](https://github.com/merlos/iOS-Open-GPX-Tracker)

If you are goint to track without Internet... don't worry! Just browse the area where you'll be tracking and it will be cached.

Open GPX Follower is an open source app (same lincense as Open GPX Tracker)

## Download Source code
This application is written in Swift. To download the code run this command in a console:

```
 git clone https://github.com/JohanDegraeve/iOS-Open-GPX-Follower.git
```

Then, to test it open the file `OpenGpxTracker.xcworkspace` with XCode.

Please note the [limitations of using Open Street Maps Tile Servers](http://wiki.openstreetmap.org/wiki/Tile_usage_policy)


## License
Open GPX Follwoer app for iOS.  Copyright (C) 2021  Johan Degraeve

based on GPX Tracker app for iOS written by Juan M. Merlos and Vincent Neo

This program is free software: you can redistribute it and/or modify
it under the terms of the **GNU General Public License** as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

----

Please note that this source code was released under the GPL license.  So any change on the code shall be made publicly available and distributed under the GPL license (this does not apply to the pods included in the project which have their own license).

----

This app uses:
- [CoreGPX Framework](https://github.com/vincentneo/CoreGPX), a SWIFT library for using GPX files. Created by [@vincentneo](http://github.com/vincentneo)

Entry on the [Open Street Maps Wiki](https://wiki.openstreetmap.org/wiki/OpenGpxTracker)

See also:
- [Avenue GPX Viewer](https://github.com/vincentneo/Avenue-GPX-Viewer), a GPX viewer based on some of the codes used in this project. A side project by collaborator [@vincentneo](http://github.com/vincentneo).
