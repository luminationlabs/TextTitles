import javax.swing.JOptionPane;

class ControlWindow extends PApplet {
  PApplet parent;
  Button prevButton, nextButton;
  Button backButton, openButton, screenButton;
  int previewHeight = 200;
  int buttonHeight = 40;
  int buttonPadding = 20;
  int buttonWidth = 100;
  int topButtonWidth = 80;
  int topButtonHeight = 40;
  int topButtonY = 10;

  ControlWindow(PApplet parent) {
    this.parent = parent;
  }
  
  public void settings() {
    size(400, previewHeight + buttonHeight + buttonPadding * 3 + topButtonHeight);
  }
  
  public void setup() {
    surface.setLocation(parent.width - width - 50, 200);  // Position ControlWindow below FileListWindow
    surface.setTitle("Controls");
    
    // Create top row buttons
    backButton = new Button("Clear", 20, topButtonY, topButtonWidth, topButtonHeight);
    screenButton = new Button("Screen", width/2 - topButtonWidth/2, topButtonY, topButtonWidth, topButtonHeight);
    openButton = new Button("Open", width - 20 - topButtonWidth, topButtonY, topButtonWidth, topButtonHeight);
    
    // Create navigation buttons aligned with preview area edges
    prevButton = new Button("◀", buttonPadding, previewHeight + buttonPadding * 2 + topButtonHeight, buttonWidth, buttonHeight);
    nextButton = new Button("▶", width - buttonPadding - buttonWidth, previewHeight + buttonPadding * 2 + topButtonHeight, buttonWidth, buttonHeight);
  }
  
  public void draw() {
    background(40);
    
    // Draw top buttons
    backButton.draw();
    screenButton.draw();
    openButton.draw();
    
    // Draw preview area
    noFill();
    stroke(60);
    rect(20, topButtonHeight + buttonPadding, width - 40, previewHeight);
    
    // Check if slides are initialized and if there's a next slide to preview
    if (((TextTitles)parent).slides != null && !((TextTitles)parent).slides.isEmpty()) {
      // Calculate the index of the next slide to preview
      int previewIndex;
      if (((TextTitles)parent).slideTransitioned) {
        previewIndex = ((TextTitles)parent).nextIndex >= ((TextTitles)parent).slides.size() - 1 ? 0 : ((TextTitles)parent).nextIndex + 1;
      } else {
        previewIndex = ((TextTitles)parent).currentIndex >= ((TextTitles)parent).slides.size() - 1 ? 0 : ((TextTitles)parent).currentIndex + 1;
      }
      
      // Display the label "Next Slide"
      fill(200);
      textSize(12);
      textAlign(CENTER, CENTER);
      text("Next Title Preview", width/2, topButtonHeight + buttonPadding + previewHeight + 12);
      
      String[] nextSlidePreview = ((TextTitles)parent).slides.get(previewIndex);
      boolean isLastSlide = (nextSlidePreview.length == 0 && previewIndex == ((TextTitles)parent).slides.size() - 1);
      
      if (isLastSlide) {
        nextSlidePreview = new String[] { "(End of slides)" };
      }

      // Determine the appropriate text size to fit the preview
      float maxWidth = width - 80; // Allow padding on sides

      for (int i = 0; i < nextSlidePreview.length; i++) {
        String line = nextSlidePreview[i];
        float previewTextSize = 20;
        float scaleFactor = 1;

        float y = topButtonHeight + buttonPadding + previewHeight/2 - (nextSlidePreview.length - 1) * previewTextSize / 2 + i * previewTextSize - previewTextSize / 2;

        textFont(createFont("Helvetica", previewTextSize));
        scaleFactor = maxWidth / textWidth(line);
        previewTextSize *= scaleFactor;
        previewTextSize = constrain(previewTextSize, 5, 20);
        textSize(previewTextSize);
        
        if (isLastSlide) {
          fill(200, 0, 0);
        } else {
          fill(200);
        }

        if (nextSlidePreview.length == 1) {
          text(nextSlidePreview[0], width/2, y);
        } else {
          if (i == 1) {
            if (((TextTitles)parent).secondLineItalics) {
              pushMatrix();
              translate(width/2, y + previewTextSize);
              shearX(-0.2);
              text(nextSlidePreview[1], 0, 0);
              popMatrix();
            } else {
              text(nextSlidePreview[1], width/2, y + previewTextSize);
            }
          } else {
            text(nextSlidePreview[0], width/2, y);
          }
        }
      }

    } else {
      fill(200);
      text("No slides loaded", width/2, topButtonHeight + buttonPadding + previewHeight/2);
    }
    
    // Draw navigation buttons
    prevButton.draw();
    nextButton.draw();
  }
  
  public void mousePressed() {
    if (backButton.isMouseOver()) {
      ((TextTitles)parent).selectedFileIndex = -1;  // Clear file selection
      ((TextTitles)parent).slides = null;  // Clear slides to show "No slides loaded"
      parent.keyCode = BACKSPACE;
      parent.keyPressed();
    } else if (openButton.isMouseOver()) {
      parent.selectFolder("Select a new folder to use:", "folderSelected", (File) null);
    } else if (screenButton.isMouseOver()) {
      String input = JOptionPane.showInputDialog("Enter the screen number of the monitor to be used for full screen presentation (requires app restart):", ((TextTitles)parent).prefs.getInt("screenNumber", 1));
      if (input != null && !input.trim().isEmpty()) {
        try {
          int screenNumber = Integer.parseInt(input.trim());
          ((TextTitles)parent).prefs.putInt("screenNumber", screenNumber);
          println("Screen number set to: " + screenNumber);
        } catch (NumberFormatException e) {
          println("Invalid screen number. Please enter a valid integer.");
        }
      }
    } else if (prevButton.isMouseOver() || nextButton.isMouseOver()) {
      if (!((TextTitles)parent).isImageFile) {  // Only handle navigation if not an image
        parent.keyCode = prevButton.isMouseOver() ? LEFT : RIGHT;
        parent.keyPressed();
      }
    }
  }
  
  public void keyPressed() {
    // Allow hotkeys in the ControlWindow
    if (keyCode == LEFT || keyCode == RIGHT) {
      if (!((TextTitles)parent).isImageFile) {  // Only handle navigation if not an image
        parent.keyCode = keyCode;
        parent.keyPressed();
      }
    } else if (keyCode == ESC) {
      parent.exit();
    }
  }
  
  class Button {
    String label;
    float x, y, w, h;
    
    Button(String label, float x, float y, float w, float h) {
      this.label = label;
      this.x = x;
      this.y = y;
      this.w = w;
      this.h = h;
    }
    
    void draw() {
      if (isMouseOver()) {
        fill(60);
      } else {
        fill(50);
      }
      noStroke();
      rect(x, y, w, h);
      
      fill(200);
      textAlign(CENTER, CENTER);
      textSize(16);
      text(label, x + w/2, y + h/2);
    }
    
    boolean isMouseOver() {
      return mouseX >= x && mouseX <= x + w && 
             mouseY >= y && mouseY <= y + h;
    }
  }
}
