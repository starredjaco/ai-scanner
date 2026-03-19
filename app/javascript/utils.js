export const disposeCharts = charts => {
    for (const chartId in charts) {
        charts[chartId].dispose();
    }
}

export const resizeCharts = charts => {
    for (const chartId in charts) {
        charts[chartId].resize();
    }
}

// Toast notification utility
// Usage: showToast('Success message', 'success')
//        showToast('Error message', 'error')
//        showToast('Info message', 'info')
export function showToast(message, type = 'info', duration = 3000) {
  const colors = {
    success: 'bg-green-500',
    error: 'bg-red-500',
    info: 'bg-blue-500',
    warning: 'bg-yellow-500'
  };

  const icons = {
    success: '<span class="icon icon-check-circle text-white" style="width: 20px; height: 20px;"></span>',
    error: '<span class="icon icon-x-circle text-white" style="width: 20px; height: 20px;"></span>',
    info: '<span class="icon icon-info text-white" style="width: 20px; height: 20px;"></span>',
    warning: '<span class="icon icon-warning text-white" style="width: 20px; height: 20px;"></span>'
  };

  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 z-50 ${colors[type] || colors.info} text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-2 transform translate-x-full transition-transform duration-300`;
  notification.innerHTML = `
    ${icons[type] || icons.info}
    <span>${message}</span>
  `;

  document.body.appendChild(notification);

  // Animate in
  setTimeout(() => {
    notification.classList.remove('translate-x-full');
  }, 100);

  // Remove after duration
  setTimeout(() => {
    notification.classList.add('translate-x-full');
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, duration);
}
