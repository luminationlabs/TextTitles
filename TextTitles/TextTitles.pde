import java.util.prefs.Preferences;
import java.io.File;
import java.io.FilenameFilter;
import java.io.PrintWriter;
import processing.data.JSONObject;
import java.util.Arrays;
import java.util.Comparator;
import javax.swing.JOptionPane;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.IOException;

int stripeHeight = 200;
int stripeBottomMargin = 50;
int fileCheckIntervalMs = 2000;  // Check open file every 2 seconds
int dirCheckIntervalMs = 10000;  // Check directory every 10 seconds
int lastDirCheckTime = 0;
int lastFileCheckTime = 0;

String[] lines;
ArrayList<String[]> slides;
int currentIndex = 0;
int reloadToIndex = -1;
int textSize = 70;
float secondLineReduction = 0.25;
boolean secondLineItalics = false;
float lineHeight = 1.15;
int textSeparation;
String directoryPath;
Preferences prefs;
File directory;
File[] files;
int selectedFileIndex = -1;
boolean showingFileList = false;  // Changed to false since we'll use a separate window
File configFile;
long lastModifiedTime;
boolean isImageFile = false;
PImage img;
int imageOrientation = 1;  // EXIF orientation value (1-8)
PImage loadingImg;  // Temporary image being loaded
int loadingOrientation = 1;  // Orientation for loading image

// Cached reflection references for metadata-extractor
Class<?> cachedMetadataClass = null;
Class<?> cachedDirectoryClass = null;
Integer cachedOrientationTag = null;
boolean metadataExtractorAvailable = true;
boolean slideTransitioned = false;
ControlWindow controlWindow;
FileListWindow fileListWindow;
boolean isMovingForward = true;
String transitionType = "fade"; // Can be "fade" or "slide"
float menuTextSize = 70;

// Variables for fade effect
float fadeProgress = 0;
float transitionDuration = 0.15;
boolean isFading = false;
int nextIndex = 0;

void settings() {
  prefs = Preferences.userRoot().node(this.getClass().getName());

  int screenNum = prefs.getInt("screenNumber", 1);
  println("Using screen number: " + screenNum);
  fullScreen(screenNum);
  // size(1920, 1080);
}

void setup() {
  // clear directory path preference (for testing)
  // prefs.remove("directoryPath");

  // Load the last used directory path
  directoryPath = prefs.get("directoryPath", null);

  // Check if directoryPath exists and is a directory
  if (directoryPath != null && !new File(directoryPath).isDirectory()) {
    directoryPath = null;
  }
  
  if (directoryPath != null) {
    folderSelected(new File(directoryPath));
  } else {
    selectFolder("Select a folder to use:", "folderSelected");
  }
  
  // Create and show the file list window
  String[] args = {"File List"};
  fileListWindow = new FileListWindow(this);
  PApplet.runSketch(args, fileListWindow);
  
  // Only create the control window if it doesn't exist
  if (controlWindow == null) {
    String[] args2 = {"Control Window"};
    controlWindow = new ControlWindow(this);
    PApplet.runSketch(args2, controlWindow);
  }
}

void folderSelected(File selection) {
  if (selection == null) {
    println("No folder was selected.");
    if (directoryPath == null) {
      exit();
    }
  } else {
    directoryPath = selection.getAbsolutePath();
    prefs.put("directoryPath", directoryPath);

    // Reset display settings
    fill(255);
    textAlign(CENTER, CENTER);
    noCursor();

    // Clear the current file and reset everything
    configFile = null;
    slides = null;
    showingFileList = true;

    // Load the new directory
    directory = new File(directoryPath);
    files = directory.listFiles(new FilenameFilter() {
      public boolean accept(File dir, String name) {
        String lowerName = name.toLowerCase();
        return lowerName.endsWith(".txt") || lowerName.endsWith(".jpg") || lowerName.endsWith(".png");
      }
    });

    // Sort the files alphabetically
    Arrays.sort(files, new Comparator<File>() {
      public int compare(File f1, File f2) {
        return f1.getName().compareToIgnoreCase(f2.getName());
      }
    });

  }
}

void keyPressed() {
  if (showingFileList) {
    if (keyCode == UP) {
      selectedFileIndex = (selectedFileIndex - 1 + files.length) % files.length;
    } else if (keyCode == DOWN) {
      selectedFileIndex = (selectedFileIndex + 1) % files.length;
    } else if (keyCode == ENTER || keyCode == RETURN) {
      if (selectedFileIndex >= 0 && selectedFileIndex < files.length) {
        File selectedFile = files[selectedFileIndex];
        if (!selectedFile.exists()) {
          println("Selected file no longer exists!");
          updateFileList();  // Refresh the file list immediately
          return;
        }
        configFile = selectedFile;
        String filename = configFile.getName().toLowerCase();
        isImageFile = filename.endsWith(".jpg") || filename.endsWith(".png");
        showingFileList = false;
        if (isImageFile) {
          // Load the image when selecting an image file
          loadImageWithOrientation(configFile.getPath());
          slides = null;  // Clear slides when loading an image
        } else {
          loadConfig();
        }
      }
    }
  } else if (isImageFile) {
    if (keyCode == LEFT || keyCode == RIGHT) {
      // Disable left/right navigation for images
      return;
    } else if (keyCode == BACKSPACE) {
      // Save current state before showing file list
      if (!isImageFile) {
        saveConfig();
      }
      showingFileList = true;
    }
  } else {
    if (keyCode == LEFT || keyCode == RIGHT) {
      if (slides != null && !slides.isEmpty() && !isFading) {
        isMovingForward = (keyCode == RIGHT);
        int direction = isMovingForward ? 1 : -1;
        
        // Calculate next index with bounds checking
        nextIndex = currentIndex + direction;
        if (nextIndex >= slides.size()) {
          nextIndex = 0;
        } else if (nextIndex < 0) {
          nextIndex = slides.size() - 1;
        }
        
        isFading = true;
        fadeProgress = 0;
      }
    } else if (keyCode == BACKSPACE) {
      // Save current state before showing file list
      if (!isImageFile) {
        saveConfig();
      }
      showingFileList = true;
    }
  }
}

void draw() {
  background(0, 0, 255);

  if (directoryPath == null) {
    return;
  }
  
  // Check if directory contents have changed every 10 seconds
  if (millis() - lastDirCheckTime > dirCheckIntervalMs) {
    lastDirCheckTime = millis();
    updateFileList();
  }
  
  if (showingFileList) {
    // Do nothing, file list is shown in separate window
  } else if (isImageFile) {
    // Check if the image file still exists
    if (!configFile.exists()) {
      println("Image file was deleted, returning to file list");
      showingFileList = true;
      configFile = null;
      img = null;
      return;
    }
    
    // Display the selected image full screen
    background(0); // Black background
    if (img != null) {
      pushMatrix();
      translate(width/2, height/2);
      
      // Apply rotation based on EXIF orientation
      applyImageOrientation(imageOrientation);
      
      // Calculate scaling to fit screen while maintaining aspect ratio
      float imgW = img.width;
      float imgH = img.height;
      
      // For 90 or 270 degree rotations, swap width and height for scaling calculation
      if (imageOrientation == 6 || imageOrientation == 8 || 
          imageOrientation == 5 || imageOrientation == 7) {
        float temp = imgW;
        imgW = imgH;
        imgH = temp;
      }
      
      float scaleW = (float)width / imgW;
      float scaleH = (float)height / imgH;
      float scale = min(scaleW, scaleH);
      
      // Draw the image centered at origin
      imageMode(CENTER);
      image(img, 0, 0, img.width * scale, img.height * scale);
      popMatrix();
    }
  } else if (slides != null && !slides.isEmpty()) {  // Ensure slides are not empty before accessing them
    // Check if the text file still exists
    if (!configFile.exists()) {
      println("Text file was deleted, returning to file list");
      showingFileList = true;
      configFile = null;
      slides = null;
      return;
    }

    // Draw the black stripe
    fill(0);
    rect(0, height - stripeHeight - stripeBottomMargin, width, stripeHeight);

    if (transitionType.equals("fade")) {
      handleFadeTransition();
    } else if (transitionType.equals("slide")) {
      handleSlideTransition();
    }

    // Check if the file has changed every 2 seconds
    if (millis() - lastFileCheckTime > fileCheckIntervalMs) {
      lastFileCheckTime = millis();
      if (configFile != null && configFile.lastModified() > lastModifiedTime) {
        lastModifiedTime = configFile.lastModified();
        reloadToIndex = currentIndex;
        loadConfig();
      }
    }
  }
}

void handleFadeTransition() {
  String[] currentSlide = slides.get(currentIndex);
  String[] nextSlide = slides.get(nextIndex);

  float adjustedTextSeparationCurrent = calculateAdjustedSeparation(currentSlide.length);
  float adjustedTextSeparationNext = calculateAdjustedSeparation(nextSlide.length);

  float yOffsetCurrent = calculateYOffset(currentSlide.length, adjustedTextSeparationCurrent);
  float yOffsetNext = calculateYOffset(nextSlide.length, adjustedTextSeparationNext);

  fill(255, 255 * (1 - fadeProgress)); // Set text color to white with fade effect
  displaySlide(currentSlide, 255 * (1 - fadeProgress), yOffsetCurrent);

  fill(255, 255 * fadeProgress); // Set text color to white with fade effect
  displaySlide(nextSlide, 255 * fadeProgress, yOffsetNext);

  // Update fade progress
  if (isFading) {
    fadeProgress += 1.0 / (transitionDuration * frameRate);
    if (fadeProgress >= 1) {
      fadeProgress = 0;
      isFading = false;
      currentIndex = nextIndex;
      slideTransitioned = false; // Reset after transition
    }
  }
}

void handleSlideTransition() {
  String[] currentSlide = slides.get(currentIndex);
  String[] nextSlide = slides.get(nextIndex);

  //float slideSpeed = stripeHeight / (transitionDuration * frameRate);
  float slideOffset = fadeProgress * stripeHeight;

  float adjustedTextSeparationCurrent = calculateAdjustedSeparation(currentSlide.length);
  float adjustedTextSeparationNext = calculateAdjustedSeparation(nextSlide.length);

  float yOffsetCurrent = calculateYOffset(currentSlide.length, adjustedTextSeparationCurrent);
  float yOffsetNext = calculateYOffset(nextSlide.length, adjustedTextSeparationNext);

  if (isMovingForward) {
    // Moving forward: slide up
    fill(255);
    displaySlide(currentSlide, 255, yOffsetCurrent - slideOffset);
    displaySlide(nextSlide, 255, yOffsetNext - slideOffset + stripeHeight);
  } else {
    // Moving backward: slide down
    fill(255);
    displaySlide(currentSlide, 255, yOffsetCurrent + slideOffset);
    displaySlide(nextSlide, 255, yOffsetNext + slideOffset - stripeHeight);
  }

  // Draw the blue background to mask the moving slides outside the stripe area
  fill(0, 0, 255);
  rect(0, 0, width, height - stripeHeight - stripeBottomMargin); // Above the stripe
  rect(0, height - stripeBottomMargin, width, stripeBottomMargin); // Below the stripe

  // Update slide progress
  if (isFading) {
    fadeProgress += 1.0 / (transitionDuration * frameRate);
    if (fadeProgress >= 1) {
      fadeProgress = 0;
      isFading = false;
      currentIndex = nextIndex;
      slideTransitioned = false; // Reset after transition
    }
  }
}

float calculateYOffset(int numberOfLines, float adjustedTextSeparation) {
  float totalHeight = (numberOfLines - 1) * adjustedTextSeparation + textSize;
  if (numberOfLines > 1) {
    totalHeight -= (textSize / 2) * secondLineReduction;
  }
  return height - stripeBottomMargin - stripeHeight + (stripeHeight - totalHeight) / 2 + textSize / 2;
}

float calculateAdjustedSeparation(int numberOfLines) {
  if (numberOfLines <= 1) return textSeparation;
  
  float totalHeight = (numberOfLines - 1) * textSeparation + textSize;
  if (totalHeight > stripeHeight) {
    // If the text is too tall, reduce the separation to fit within the stripe
    return (stripeHeight - textSize) / (numberOfLines - 1);
  }
  return textSeparation;
}

void displaySlide(String[] slide, float alpha, float yPosition) {
  if (slide == null || slide.length == 0) return;
  
  textAlign(CENTER, CENTER);
  float maxAllowedWidth = width - 100; // Allow for some padding on the sides
  
  for (int i = 0; i < slide.length; i++) {
    String textLine = slide[i];
    float adjustedY = yPosition + i * textSeparation;
    float scaleFactor = 1;

    // Check if text width exceeds allowed width
    textSize(textSize);
    float textWidthValue = textWidth(textLine);
    if (textWidthValue > maxAllowedWidth) {
      // Calculate a scaling factor to reduce the text size
      scaleFactor = maxAllowedWidth / textWidthValue;
    }
    
    if (i == 1) {
      float secondLineScale = (1 - secondLineReduction);
      if (scaleFactor < secondLineScale) {
        // If scaleFactor is already less than secondLineScale, don't reduce it further
        secondLineScale = 1;
      }
      if (secondLineItalics) {
        pushMatrix();
        translate(width/2, adjustedY);
        textSize(textSize * scaleFactor * secondLineScale);
        shearX(-0.2);
        fill(255, alpha);
        text(textLine, 0, 0);
        popMatrix();
        continue;  // Skip the normal text drawing for italics
      } else {
        textSize(textSize * scaleFactor * secondLineScale);
      }
    } else {
      textSize(textSize * scaleFactor);
    }
    
    // Draw the text
    fill(255, alpha);
    text(textLine, width/2, adjustedY);
  }
}

void exit() {
  if (!showingFileList && !isImageFile) {
    saveConfig();
  }
  
  // Close windows in sequence
  if (controlWindow != null) {
    controlWindow.dispose();
    controlWindow = null;
  }
  if (fileListWindow != null) {
    fileListWindow.dispose();
    fileListWindow = null;
  }
  
  // Call super.exit() after a brief delay to allow windows to close
  new Thread(() -> {
    try {
      Thread.sleep(100);
      super.exit();
    } catch (InterruptedException e) {
      super.exit();
    }
  }).start();
}

void saveConfig() {
  if (configFile == null || isImageFile || !configFile.exists()) return;
  
  // Create JSON configuration
  JSONObject config = new JSONObject();
  config.setInt("textSize", textSize);
  config.setFloat("secondLineReduction", secondLineReduction);
  config.setBoolean("secondLineItalics", secondLineItalics);
  config.setFloat("lineHeight", lineHeight);
  config.setInt("currentIndex", currentIndex);
  config.setString("transitionType", transitionType);

  // Print "Saving index x for file y" message
  String message = "Saving slide index " + currentIndex + " for: " + configFile.getName();
  println(message);
  
  try {
    // Read all lines after the JSON config
    ArrayList<String> contentLines = new ArrayList<String>();
    String[] fileLines = loadStrings(configFile.getPath());
    
    if (fileLines != null) {
      int i = 0;
      // Skip existing JSON configuration
      while (i < fileLines.length && !fileLines[i].trim().isEmpty()) {
        i++;
      }
      // Skip the blank line if it exists
      if (i < fileLines.length) {
        i++;
      }
      // Add remaining content lines
      while (i < fileLines.length) {
        contentLines.add(fileLines[i]);
        i++;
      }
    }
    
    // Write back to file
    PrintWriter output = createWriter(configFile.getPath());
    output.println(config.toString());
    output.println();  // Blank line separator
    for (String line : contentLines) {
      output.println(line);
    }
    output.flush();
    output.close();
  } catch (Exception e) {
    println("Error saving config: " + e.getMessage());
  }
}

void loadConfig() {
  if (configFile == null || isImageFile || !configFile.exists()) {
    slides = null;
    return;
  }

  try {
    // Read all lines from the file
    lines = loadStrings(configFile.getPath());
    if (lines == null || lines.length == 0) {
      slides = null;
      return;
    }

    // Read JSON configuration from the first lines until a blank line
    StringBuilder jsonString = new StringBuilder();
    int i = 0;
    while (i < lines.length && !lines[i].trim().isEmpty()) {
      jsonString.append(lines[i]);
      i++;
    }
    
    // Try to parse JSON configuration if present
    try {
      if (jsonString.length() > 0) {
        JSONObject config = JSONObject.parse(jsonString.toString());
        textSize = config.hasKey("textSize") ? config.getInt("textSize") : textSize;
        secondLineReduction = config.hasKey("secondLineReduction") ? config.getFloat("secondLineReduction") : secondLineReduction;
        secondLineItalics = config.hasKey("secondLineItalics") ? config.getBoolean("secondLineItalics") : secondLineItalics;
        lineHeight = config.hasKey("lineHeight") ? config.getFloat("lineHeight") : lineHeight;
        transitionType = config.hasKey("transitionType") ? config.getString("transitionType") : transitionType;
        
        // Load the saved currentIndex if it exists in config and reloadToIndex is not set
        if (config.hasKey("currentIndex") && reloadToIndex < 0) {
          currentIndex = config.getInt("currentIndex");
        }
      }
    } catch (Exception e) {
      // If JSON parsing fails, just use default values and start from the beginning
      println("No valid JSON configuration found, using default values");
      i = 0;
    }

    // Calculate text separation based on line height and text size
    textSeparation = (int)(textSize * lineHeight);
    
    // Process the remaining lines as slides
    ArrayList<String[]> newSlides = new ArrayList<String[]>();
    ArrayList<String> currentSlide = new ArrayList<String>();
    
    for (; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty()) {
        if (currentSlide.size() > 0) {
          newSlides.add(currentSlide.toArray(new String[0]));
          currentSlide.clear();
        }
      } else {
        currentSlide.add(line);
      }
    }
    
    // Add the last slide if it's not empty
    if (currentSlide.size() > 0) {
      newSlides.add(currentSlide.toArray(new String[0]));
    }
    
    // Always add an empty slide at the end
    newSlides.add(new String[0]);
    
    slides = newSlides;
    
    // Update lastModifiedTime
    lastModifiedTime = configFile.lastModified();
    
    // If we're reloading to a specific index, use it
    if (reloadToIndex >= 0) {
      currentIndex = reloadToIndex;
      reloadToIndex = -1;
    }
    
    // Ensure currentIndex is within bounds
    if (slides != null && slides.size() > 0) {
      currentIndex = Math.min(Math.max(currentIndex, 0), slides.size() - 1);
      // Reset nextIndex to avoid out of bounds when switching files
      nextIndex = currentIndex;
      isFading = false;
    } else {
      currentIndex = 0;
    }
  } catch (Exception e) {
    println("Error loading config: " + e.getMessage());
    slides = null;
  }
}

void updateFileList() {
  if (directory == null || !directory.exists()) {
    println("Directory no longer exists!");
    return;
  }

  // Load the new directory contents
  File[] newFiles = directory.listFiles(new FilenameFilter() {
    public boolean accept(File dir, String name) {
      String lowerName = name.toLowerCase();
      return lowerName.endsWith(".txt") || lowerName.endsWith(".jpg") || lowerName.endsWith(".png");
    }
  });

  // Sort the files alphabetically
  Arrays.sort(newFiles, new Comparator<File>() {
    public int compare(File f1, File f2) {
      return f1.getName().compareToIgnoreCase(f2.getName());
    }
  });

  // Check if the files array has changed
  boolean filesChanged = false;
  if (files == null || files.length != newFiles.length) {
    filesChanged = true;
  } else {
    for (int i = 0; i < files.length; i++) {
      if (!files[i].getAbsolutePath().equals(newFiles[i].getAbsolutePath())) {
        filesChanged = true;
        break;
      }
    }
  }

  if (filesChanged) {
    println("Directory contents changed, updating file list");
    files = newFiles;
    
    // If we're showing the file list and have a selection, make sure it's still valid
    if (showingFileList && selectedFileIndex >= 0) {
      if (selectedFileIndex >= files.length) {
        selectedFileIndex = files.length - 1;
      }
    }
  }
}

void loadImageWithOrientation(String imagePath) {
  // Get orientation before loading
  loadingOrientation = getImageOrientation(imagePath);
  
  // Load the image into temporary variable
  try {
    File imageFile = new File(imagePath);
    BufferedImage buffImg = ImageIO.read(imageFile);
    if (buffImg != null) {
      loadingImg = new PImage(buffImg);
    } else {
      loadingImg = loadImage(imagePath);
    }
  } catch (IOException e) {
    loadingImg = loadImage(imagePath);
  }
  
  // Once loaded successfully, swap to main image
  if (loadingImg != null) {
    img = loadingImg;
    imageOrientation = loadingOrientation;
    loadingImg = null;  // Clear loading image
  }
}

int getImageOrientation(String imagePath) {
  if (!metadataExtractorAvailable) {
    return 1; // Skip if we know it's not available
  }
  
  // Try metadata-extractor if available
  try {
    // Cache the classes on first use
    if (cachedMetadataClass == null) {
      cachedMetadataClass = Class.forName("com.drew.imaging.ImageMetadataReader");
      cachedDirectoryClass = Class.forName("com.drew.metadata.exif.ExifIFD0Directory");
      cachedOrientationTag = (Integer) cachedDirectoryClass.getField("TAG_ORIENTATION").get(null);
    }
    
    Object metadata = cachedMetadataClass.getMethod("readMetadata", File.class).invoke(null, new File(imagePath));
    Object exifDirectory = metadata.getClass().getMethod("getFirstDirectoryOfType", Class.class).invoke(metadata, cachedDirectoryClass);
    
    if (exifDirectory != null) {
      Boolean hasTag = (Boolean) exifDirectory.getClass().getMethod("containsTag", int.class).invoke(exifDirectory, cachedOrientationTag);
      
      if (hasTag) {
        return (Integer) exifDirectory.getClass().getMethod("getInt", int.class).invoke(exifDirectory, cachedOrientationTag);
      }
    }
  } catch (ClassNotFoundException e) {
    // metadata-extractor not available
    metadataExtractorAvailable = false;
  } catch (Exception e) {
    // Failed to read metadata for this image
  }
  
  return 1; // Default orientation
}

void applyImageOrientation(int orientation) {
  switch(orientation) {
    case 1: // Normal
      break;
    case 2: // Flip horizontal
      scale(-1, 1);
      break;
    case 3: // Rotate 180
      rotate(PI);
      break;
    case 4: // Flip vertical
      scale(1, -1);
      break;
    case 5: // Transpose
      rotate(PI/2);
      scale(1, -1);
      break;
    case 6: // Rotate 90 CW
      rotate(PI/2);
      break;
    case 7: // Transverse
      rotate(PI/2);
      scale(-1, 1);
      break;
    case 8: // Rotate 270 CW
      rotate(-PI/2);
      break;
  }
}
