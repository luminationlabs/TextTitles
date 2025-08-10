import processing.core.*;
import processing.event.MouseEvent;

class FileListWindow extends PApplet {
  PApplet parent;
  int listStartY = 0;
  int itemHeight = 30;
  float scrollSpeed = 20;
  
  FileListWindow(PApplet parent) {
    this.parent = parent;
  }
  
  public void settings() {
    size(400, 600, P2D);  // Use P2D renderer to enable smooth resizing
  }
  
  public void setup() {
    surface.setLocation(parent.width - width - 50, 0);  // Position FileListWindow on the right side, near top
    surface.setResizable(true);
    textAlign(LEFT, CENTER);
    surface.setTitle("File List");
  }
  
  private String getDisplayName(File file) {
    String name = file.getName();
    String nameLower = name.toLowerCase();
    
    // Check if it's a .txt file
    if (nameLower.endsWith(".txt")) {
      // Remove .txt extension
      return name.substring(0, name.length() - 4);
    }
    
    // Check if it's an image file (only .jpg and .png supported)
    if (nameLower.endsWith(".jpg") || nameLower.endsWith(".png")) {
      // Find the last dot to remove extension
      int lastDot = name.lastIndexOf('.');
      if (lastDot > 0) {
        return "■ " + name.substring(0, lastDot);
      }
    }
    
    // For all other files, return as-is
    return name;
  }
  
  public void draw() {
    background(40);
    
    if (((TextTitles)parent).files != null) {
      // Calculate total content height
      int totalHeight = ((TextTitles)parent).files.length * itemHeight;
      
      // If content is shorter than window, reset scroll position
      if (totalHeight <= height) {
        listStartY = 0;
      } else {
        // Ensure scroll position is valid after resize
        listStartY = constrain(listStartY, -(totalHeight - height), 0);
      }
      
      pushMatrix();
      translate(0, listStartY);
      
      for (int i = 0; i < ((TextTitles)parent).files.length; i++) {
        float y = i * itemHeight;
        
        // Only draw items that are visible in the window
        if (y + listStartY >= -itemHeight && y + listStartY <= height) {
          if (i == ((TextTitles)parent).selectedFileIndex) {
            fill(60);
            noStroke();
            rect(0, y, width, itemHeight);
          }
          
          fill(i == ((TextTitles)parent).selectedFileIndex ? 255 : 200);
          textSize(14);
          text(getDisplayName(((TextTitles)parent).files[i]), 10, y, width - 20, itemHeight);  // Use formatted display name
        }
      }
      
      popMatrix();
    }
  }
  
  public void mousePressed() {
    if (((TextTitles)parent).files != null) {
      int clickedIndex = floor((mouseY - listStartY) / itemHeight);
      if (clickedIndex >= 0 && clickedIndex < ((TextTitles)parent).files.length) {
        // Save current file's state before switching
        if (((TextTitles)parent).configFile != null && !((TextTitles)parent).isImageFile) {
          ((TextTitles)parent).saveConfig();
        }
        
        ((TextTitles)parent).selectedFileIndex = clickedIndex;
        ((TextTitles)parent).configFile = ((TextTitles)parent).files[clickedIndex];
        String filename = ((TextTitles)parent).configFile.getName().toLowerCase();
        ((TextTitles)parent).isImageFile = filename.endsWith(".jpg") || filename.endsWith(".png");
        ((TextTitles)parent).showingFileList = false;  // Set to false to show the file
        if (((TextTitles)parent).isImageFile) {
          // Load the image when selecting an image file
          ((TextTitles)parent).loadImageWithOrientation(((TextTitles)parent).configFile.getPath());
          ((TextTitles)parent).slides = null;  // Clear slides when loading an image
        } else {
          ((TextTitles)parent).img = null;  // Clear image when switching to text
          ((TextTitles)parent).loadConfig();
        }
        parent.redraw();  // Force the parent window to update
      }
    }
  }
  
  public void mouseWheel(MouseEvent event) {
    if (((TextTitles)parent).files != null) {
      int totalHeight = ((TextTitles)parent).files.length * itemHeight;
      
      // Only scroll if content is taller than window
      if (totalHeight > height) {
        float e = event.getCount();
        listStartY -= (int)(e * scrollSpeed);
        listStartY = constrain(listStartY, -(totalHeight - height), 0);
      }
    }
  }
  
  public void keyPressed() {
    // Allow hotkeys in the FileListWindow
    if (keyCode == UP || keyCode == DOWN) {
      if (((TextTitles)parent).files != null) {
        // Save current file's state before switching
        if (((TextTitles)parent).configFile != null && !((TextTitles)parent).isImageFile) {
          ((TextTitles)parent).saveConfig();
        }
        
        if (keyCode == UP) {
          ((TextTitles)parent).selectedFileIndex = (((TextTitles)parent).selectedFileIndex - 1 + ((TextTitles)parent).files.length) % ((TextTitles)parent).files.length;
        } else {
          ((TextTitles)parent).selectedFileIndex = (((TextTitles)parent).selectedFileIndex + 1) % ((TextTitles)parent).files.length;
        }
        
        // Auto-scroll to keep selected item visible
        float selectedY = ((TextTitles)parent).selectedFileIndex * itemHeight;
        int totalHeight = ((TextTitles)parent).files.length * itemHeight;
        
        if (totalHeight > height) {
          if (selectedY + listStartY < 0) {
            listStartY = -(int)selectedY;
          } else if (selectedY + listStartY > height - itemHeight) {
            listStartY = (int)(height - itemHeight - selectedY);
          }
          listStartY = constrain(listStartY, -(totalHeight - height), 0);
        }
        
        ((TextTitles)parent).configFile = ((TextTitles)parent).files[((TextTitles)parent).selectedFileIndex];
        String filename = ((TextTitles)parent).configFile.getName().toLowerCase();
        ((TextTitles)parent).isImageFile = filename.endsWith(".jpg") || filename.endsWith(".png");
        if (((TextTitles)parent).isImageFile) {
          // Load the image when selecting an image file
          ((TextTitles)parent).loadImageWithOrientation(((TextTitles)parent).configFile.getPath());
          ((TextTitles)parent).slides = null;  // Clear slides when loading an image
        } else {
          ((TextTitles)parent).img = null;  // Clear image when switching to text
          ((TextTitles)parent).loadConfig();
        }
      }
    } else if (keyCode == ENTER || keyCode == RETURN) {
      // Open the selected file when Enter is pressed
      if (((TextTitles)parent).files != null && ((TextTitles)parent).selectedFileIndex >= 0 && ((TextTitles)parent).selectedFileIndex < ((TextTitles)parent).files.length) {
        // Save current file's state before switching
        if (((TextTitles)parent).configFile != null && !((TextTitles)parent).isImageFile) {
          ((TextTitles)parent).saveConfig();
        }
        
        ((TextTitles)parent).configFile = ((TextTitles)parent).files[((TextTitles)parent).selectedFileIndex];
        String filename = ((TextTitles)parent).files[((TextTitles)parent).selectedFileIndex].getName().toLowerCase();
        ((TextTitles)parent).isImageFile = filename.endsWith(".jpg") || filename.endsWith(".png");
        ((TextTitles)parent).showingFileList = false;  // Set to false to show the file
        if (((TextTitles)parent).isImageFile) {
          // Load the image when selecting an image file
          ((TextTitles)parent).loadImageWithOrientation(((TextTitles)parent).configFile.getPath());
          ((TextTitles)parent).slides = null;  // Clear slides when loading an image
        } else {
          ((TextTitles)parent).img = null;  // Clear image when switching to text
          ((TextTitles)parent).loadConfig();
        }
        parent.redraw();  // Force the parent window to update
      }
    } else if (keyCode == LEFT || keyCode == RIGHT) {
      // Pass left/right events to both parent and control window
      ((TextTitles)parent).keyCode = keyCode;
      ((TextTitles)parent).keyPressed();
      if (((TextTitles)parent).controlWindow != null) {
        ((TextTitles)parent).controlWindow.keyCode = keyCode;
        ((TextTitles)parent).controlWindow.keyPressed();
      }
    } else if (keyCode == ESC) {
      // Handle ESC key - call parent's exit method
      parent.exit();
    } else {
      // Pass other key events to parent
      ((TextTitles)parent).keyCode = keyCode;
      ((TextTitles)parent).keyPressed();
    }
  }
}
