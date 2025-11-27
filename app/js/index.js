import cytoscape from 'cytoscape';
import cola from 'cytoscape-cola';
import fcose from 'cytoscape-fcose';

cytoscape.use(cola);
cytoscape.use(fcose);

window.cytoscape = cytoscape;

// Simple tooltip handler - just show/hide a basic tooltip
// Avoids all jQuery UI and Bootstrap conflicts
let activeTooltip = null;

$(document).on('mouseenter', '[data-toggle="tooltip"]', function(e) {
  // Remove any existing tooltip first
  if (activeTooltip) {
    activeTooltip.remove();
    activeTooltip = null;
  }
  
  const $target = $(e.currentTarget);
  const title = $target.attr('title') || $target.data('original-title');
  
  if (!title) return;
  
  // Save and remove title to prevent browser tooltip
  if (!$target.data('original-title')) {
    $target.data('original-title', title).removeAttr('title');
  }
  
  // Create tooltip
  const tooltip = $('<div class="custom-tooltip"></div>')
    .html(title)
    .css({
      position: 'absolute',
      backgroundColor: '#000',
      color: '#fff',
      padding: '5px 10px',
      borderRadius: '4px',
      fontSize: '12px',
      zIndex: 99999,
      maxWidth: '300px',
      wordWrap: 'break-word',
      pointerEvents: 'none'
    })
    .appendTo('body');
  
  // Position it
  const offset = $target.offset();
  const placement = $target.data('placement') || 'bottom';
  
  if (placement === 'top') {
    tooltip.css({
      top: offset.top - tooltip.outerHeight() - 5,
      left: offset.left + ($target.outerWidth() - tooltip.outerWidth()) / 2
    });
  } else {
    tooltip.css({
      top: offset.top + $target.outerHeight() + 5,
      left: offset.left + ($target.outerWidth() - tooltip.outerWidth()) / 2
    });
  }
  
  activeTooltip = tooltip;
});

$(document).on('mouseleave', '[data-toggle="tooltip"]', function() {
  if (activeTooltip) {
    activeTooltip.remove();
    activeTooltip = null;
  }
});

export function initRadioSync() {
  console.log("initRadioSync loaded");

  $(document).on('change', 'input[type="radio"]', function() {
    const inputName = $(this).attr('name');
    if (inputName && inputName.includes('visual_check') && inputName.includes('-')) {
      const rowIndex = parseInt($(this).closest('.fusion-radio-group').data('row'));
      const selectedValue = $(this).val();
      const namespaceId = inputName.replace(/_\d+$/, '') + '_changed';

      Shiny.setInputValue(namespaceId, {
        row: rowIndex,
        value: selectedValue,
        timestamp: new Date().getTime()
      });
      console.log("Radio change: ", selectedValue);
    }
  });
}

// registrace listeneru pro ruční spuštění
Shiny.addCustomMessageHandler("initRadioSync", function(message) {
  initRadioSync();
});
