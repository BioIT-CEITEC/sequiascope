import cytoscape from 'cytoscape';
import cola from 'cytoscape-cola';
import fcose from 'cytoscape-fcose';

cytoscape.use(cola);
cytoscape.use(fcose);

window.cytoscape = cytoscape;

// Initialize Bootstrap tooltips with faster delay
$(document).ready(function() {
  // Enable tooltips with shorter delay
  $('[title]').tooltip({
    delay: { show: 100, hide: 100 }
  });
  
  // Re-initialize tooltips when new elements are added
  const observer = new MutationObserver(function() {
    $('[title]:not([data-bs-original-title])').tooltip({
      delay: { show: 100, hide: 100 }
    });
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
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
