---
title:  "Generating Memoji From Photos"
---

# Generating Memoji from Photos

Are you satisfied with your Memoji? :)  Did you feel a bit lost when trying to choose the right chin or eyes?  Wouldn't it be cool if an algorithm could generate a Memoji from a photo?

This is my attempt at using a neural network to generate Apple Memoji characters from real world photos of people.  Specifically, I tested _VGG16 Face_, a network trained for face recognition to see how well, if at all, it would perform when comparing real world photos with Memoji that "look like" various subjects.  I then attempted to use it to guide the selection of features and create Memoji for new subjects.

<p align="center">
<img height="320" src="/assets/memoji-gen/trump-gen.png">
</p>

<p align="center">
<img height="335" src="/assets/memoji-gen/obama-gen.png">
</p>


<p align="center">
_Memoji generated from photos with guidance from a neural network:  The first example above included one subjective choice explained below._
</p>


## Limitations

Although I think the results are compelling, let me temper expectations a bit by talking about some of the limitations.  

### Caricatures

First, there is the subjectivity of what "looks like" someone in a cartoonish form.  Usually these caricatures exaggerate a person's most distinctive features.  Some of these features, such as hair style, are not really intrinsic to the person but vary wildly from photo to photo and day to day.  For this reason it's likely that a good neural network trained to recognize individuals would capture information about hair style in an abstract way that allows for this variation and may not be ideal for generating hairstyles.

### Skin Tone
Accurately inferring skin tone from photos taken in random lighting conditions is a hard.  My simple test setup did a poor job at this.  It generally produced lighter skin choices and didn't always differentiate well between realistic and unrealistic options (not shown)

<p align="center">
  <img height="350" src="/assets/memoji-gen/skin-tone.png">
</p>

This article on normalizing facial features and skin tone looks pretty cool: <a href="https://arxiv.org/pdf/1701.04851.pdf">Synthesizing Normalized Faces from Facial Identity Features</a>

### Lack of an API
We are seriously limited by the fact that there is currently no API for creating Apple Memoji, nor any other straightforward way to automate their creation in iOS.  This drastically limits how effectively we can search the space of possible Memoji as part of any generation process.  Ideally we'd want to use a genetic algorithm to to exhaustively refine combinations of features rather than rely on their separability, but this was not possible with the simple route I chose here.

Finally, I'll just say here that I am not really an expert in this field and I welcome all feedback, corrections, and suggestions.  

### Photo Selection

The choice of which photos to include as reference material has a large impact on the result.  Some photos produced subjectively better results than others and in many cases it wasn't clear to me why.  In general I tried to find representative, tightly cropped, forward facing photos.  As I'll discuss below, for each feature choice I averaged scores based on at least four reference photos.


## The Network and Setup

The actual code for these tests was very small because of the great tools available today.  I'll run through the setup and link to the source at the end.

#### VGG
VGG is a popular convolutional neural network architecture used in image recognition. <a href="http://www.robots.ox.ac.uk/~vgg/software/vgg_face/">_VGG Face_</a> is an implementation of that architecture that has been trained specifically to recognize faces. The creators of _VGG Face_ have made the fully trained network (the layer details and learned weights required to run the network) available to download and use. This is what makes goofy experiments like mine possible. Training a network like this from scratch requires a prohibitive amount of finely curated data and a lot of compute time.  The downloadable weights file representing the final trained network is half a gigabyte itself.

<p align="center">
  <img width="640" src="/assets/memoji-gen/vgg-face.png">
  <br/>
<a src=" https://www.omicsonline.org/open-access/face-verification-subject-to-varying-age-ethnicity-and-genderdemographics-using-deep-learning-2155-6180-1000323.php?aid=82636">image source</a>
</p>

#### Torch

For these tests I used the <a href="http://torch.ch/">Torch</a> scientific computing framework.  Torch provides the environment needed to run the VGG model.  It offers a scripting environment based on _Lua_, with libraries for performing math on Tensors (high dimensional arrays of numbers) and primitive building blocks for the layers of the neural network. I chose Torch simply because it's one I've used before. (I'm not a big fan of Lua but it will do for this.)

Torch can load the provided VGG Face model for us and run an image through it with just a few lines of code. The basic flow is:

```lua
-- Load the network
net = torch.load('./torch_model/VGG_FACE.t7')
net:evaluate()

-- Apply an image
img = load_image(my_file)
output = net:forward(img)
```

There are a couple of steps involved in loading and preparing the image, which you can find in the supplied source code.

#### The Layers

As shown in the diagram above, VGG composes layers of different types. Starting with a Tensor holding the RGB image data, it applies a series of convolutions, poolings, weightings, and other types of transformations that change the dimensionality of the data at each layer as they learn more and more abstract features. Ultimately the network produces a one dimensional, 2622 element prediction vector from the final layer.  This vector represents the probabilities of matching each of a set of specific people in the training data set.  

In our case we do not care about those predictions but instead we want to use the network to compare our own sets of arbitrary faces.  To do this we can utilize the output of a layer just below the prediction layer in the hierarchy.  This layer is a 4096 element vector that can be thought of as characterizing the features of a face.

```Lua
output = net.modules[selectedLayer].output:clone()
```
While VGG16 is nominally a 16 layer sandwich, the actual implementation in Torch (and its neural network library _nn_) yields a 40 "module" setup.  In this scheme layer 38 gives us what we want.

#### Similarity

What we're going to do is essentially just run pairs of images through the network and compare the respective outputs using a simple similarity metric. One way to compare two very large vectors of numbers is with a dot product:

```lua
  torch.dot(output1, output2)
```
This produces a scalar value that you can think of as representing how much the vectors are "aligned" in their high dimensional space.

For this test we want to compare a prospective Memoji with multiple reference images and combine the results.  To do this I normalized the value for each pair and I averaged them.

```lua
sum = 0
for i = 1, #refs do
  local ref  = refs[i]
  local dotself = torch.dot(ref , ref) -- for normalization
  sum = sum + torch.dot(ref, target) / dotself
end
...
return sum / #refs
```

The normalization means that the score for comparing an image to itself would yield 1.0.  So for later reference higher "score" numbers mean greater similarity.

There are many other types of metrics we could use.  Two other obvious possibilities are a euclidean distance or a mean squared error measure.  I briefly experimented with both of these but for reasons that I do not understand the dot product seemed to produce the best results.  (If you try swapping those in don't forget that a distance or error measure would produce smaller values for better correspondence rather than larger as above.)

## A First Test - The Lineup

The first thing I wanted to validate was whether or not the face network would work with cartoonish Memoji faces at all.  I started by grabbing a random collection of about 64 human looking Memoji from a google image search.  (Most of these came from Apple's demos).

<p align="center">
  <img height="350" src="/assets/memoji-gen/memoji-all.png">
</p>

I then chose one and asked the network to rank all of the Memoji and show me the top three picks based on this single reference.

<p align="center">
  <img height="190" src="/assets/memoji-gen/lineup2.png">
</p>

The results are encouraging!  Not only did it find the identical Memoji (ranked first with a score of 1.0) but the second and third choices were plausible too.

### Real photos

Now comes the "real" test: What would the network make of a real world photo when compared with these Memoji?  I grabbed some photos of famous people and these were the results:

<p align="center">
  <img height="400" src="/assets/memoji-gen/trump-picks-all.png">
</p>
<p align="center">
  <img height="400" src="/assets/memoji-gen/obama-picks-all.png">
</p>

Ok, well, the results are interesting anyway, right? :) Keep in mind the limited set of Memoji that it had to choose among and that the dominant features the network is seeing in these images may not be what we expect. Also note how much lower the scores (the "confidences") in these comparisons than when comparing Memoji to other Memoji.  

Let's move on :)

## The "Generation" Process

Ok, so now let's try to turn this around and create some Memoji using the network to pick features.
This is where it gets sticky.  There's no API for creating Memoji with code and therefore no obvious way to have an algorithm create one.  While there would certainly be ways to do this with a jailbroken iOS device or by hacking together captured artwork, I'm going to take an easier route and just help the script push the buttons.

For the test rig I tethered my phone to my desktop with Quicktime Player's Movie Recording feature and positioned it in a corner where the script could grab screenshots for processing.  For each feature I ran through the possibilities, selecting each option and hitting enter on the keyboard to grab and rank the output.

<p align="center">
  <img height="300" src="/assets/memoji-gen/desktop1.png">
</p>

This is obviously not ideal for several reasons:  First, it's a pain. (There are 93 hair choices by the way; Try running through those dozens of times.)  More importantly, it only allows us to evaluate one feature difference at a time.  In theory we could iterate on this and run through the tree of choices repeatedly until there were no changes suggested by the network,  but even that isn't perfect since it might only be a "local minimum" based on how we started.  

Did I mention that there are 93 hair choices? :)

Let's go with this and see what happens.

## Results

I spoiled most of the results with the images at the beginning of this article, but they could use a little elaboration.

First, let me say that I only made one subjective pick (tweak) in two Presidential examples and that was to override President Trump's hair.  So with that exception, to the extent that you think the generated examples do or do not look like their counterparts that is all due to the network's rankings.

I've already mentioned that skin tone was not differentiated very well at all, although in the Memoji selection test it did seem to make some correspondence?

Some characteristics did what I expected.  For example, President Obama is known to have somewhat prominent ears and the network did rank the choices from largest to smallest.

<p align="center">
  <img height="200" src="/assets/memoji-gen/obama-ears.png">
  <br/><em>Obama's ear selection</em>
</p>

But the choice of eyes seems more random.  By this I mean that the top three choices did not seem paticularly similar to one another.

<p align="center">
  <img height="200" src="/assets/memoji-gen/obama-eyes.png">
  <br/><em>Obama's eye selection</em>
</p>

President Trump's hair selection varied wildly.

<p align="center">
  <img height="200" src="/assets/memoji-gen/trump-hair.png">
  <br/><em>Trump's hair selection</em>
</p>

And so for the purposes of the banner shot for the article I took the liberty of changing the hair.  (Note that the choices below don't reflect the final eye color, but the network did later choose blue).

President Trump's eye selection on the other hand was more consistent:

<p align="center">
  <img height="200" src="/assets/memoji-gen/trump-eyes.png">
  <br/><em>Trump's eye selection</em>
</p>

President Obama's chin looks overly square to my eye, but after staring at it for a while now it kind of looks right to me.   (This is the danger of letting too much subjectivity creep into this.)

Finally, I should also note that I did not bother with facial hair selection for either President since they have none.  (I probably should have.)

### The source

You can get the Torch scripts that I used in this article at the github project: <a href="">memoji-face</a>. 
I probably won't include the images with the scripts just to avoid complaints, but if anyone wants to reproduce my results with the same data please contact me directly and I will send them to you.

The full VGG Face network can be downloaded from the
<a href="http://www.robots.ox.ac.uk/~vgg/software/vgg_face/">Visual Geometry Group VGG Face</a> web site.


## Me?

Pat Niemeyer is a co-founder and software engineer at Present Company.  He is the author of the Learning Java book series by O'Reilly & Associates and contributes to various open source projects.

<p align="center">
  <img height="320" src="/assets/memoji-gen/pat-gen.png">
</p>
