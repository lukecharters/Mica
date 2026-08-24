# Add an MDM catalogue icon preview size



It’s best to do this in a dev/test environment. If your dev environment also happens to be your prod environment then try and keep this scoped to only your machine or a test group.

1. Create a dummy item or duplicate an existing item in your MDM’s catalogue application where you can change the icon.
2. Change the icon to an image with edge to edge colour. Don’t use an app icon with transparent padding. There are images you can download from the repo here: 
3. Open your MDM catalogue application and take a screenshot of the item, you don't have to get the edges perfectly (cmd+shift+4). If the icon is a different size in the catalogue view and single item view, capture both.
4. Open the image in Preview and drag the selection marquee around the image to the edges.

Either open an issue and let me know the name of your MDM catalogue app and the measured sizes or post the same info in the `#mica` channel on the Mac Admins Slack.
Alternatively, you can clone the repo