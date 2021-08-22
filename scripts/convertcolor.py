#! /usr/bin/python
import os
import sys

# opens all png en jpg files in specified folder, reads pixel by pixel, any pixel that is different from specific color, is changed to other specific color
# rotates the image
# saves new image in same file
#
# takes one parameter : directory name


from PIL import Image

directory = sys.argv[1]

for filename in os.listdir(directory):
   
   if filename.endswith(".jpg") or filename.endswith(".png"):
      print filename

      im = Image.open(directory + '/' + filename)

      # iterate through pixels
      for x in range(im.width):
         for y in range(im.height):

             # if pixel is not black then change to other color 
             if im.getpixel((x,y))[:3] != (35,31,32):
                im.putpixel((x,y), (20, 255,1))

      # rotate 180 degrees
      im_rot_180 = im.rotate(180)

      # save the new image in same file
      im_rot_180.save(directory + '/' + filename)
