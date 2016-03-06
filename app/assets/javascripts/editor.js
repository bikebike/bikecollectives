(function() {
	var pen;
	var editor = document.getElementById('editor');
	var editActions = document.getElementById('edit-actions');
	var createActions = document.getElementById('create-actions');
	var editButton = document.getElementById('edit-content');
	var statusSelect = document.getElementById('organization_status');
	var editing = false;
	var oldText = null;

	if (editor.className === 'new') {
		startEditing();
	} else {
		editor.onclick = function() { if (!editing) { startEditing(); } };
		editor.addEventListener('keydown', function(event) {
			if (!editing) {
				if (event.keyCode == 13) {
					startEditing();
				}
				return true;
			}
		});
		document.getElementById('cancel-edit-content').onclick = function(event) {
			event.preventDefault();
			if (oldText) {
				editor.innerHTML = oldText;
			}
			stopEditing();
		};
	}

	function startEditing(event) {
		if (event) {
			event.preventDefault();
		}
		pen = new Pen({
			editor: editor,
			class: 'pen',
			textarea: '<textarea name="organization[info]"></textarea>',
			list: ['p', 'h3', 'h4', 'blockquote', 'insertorderedlist', 'insertunorderedlist', 'bold', 'italic', 'underline', 'strikethrough', 'createlink', 'insertimage'],
			title: {
				'p': 'Paragraph',
				'h3': 'Major Heading',
				'h4': 'Minor Heading',
				'blockquote': 'Quotation',
				'insertorderedlist': 'Ordered List',
				'insertunorderedlist': 'Unordered List',
				'bold': 'Bold',
				'italic': 'Italic',
				'underline': 'Underline',
				'strikethrough': 'Strikethrough',
				'createlink': 'Link',
				'insertimage': 'Image'
			}
		});
		if (editActions) {
			editActions.className = 'editing';
		}
		editing = true;
		oldText = editor.innerHTML;
		editor.focus();
	}

	function stopEditing() {
		if (pen) {
			pen.destroy();
		}
		if (editActions) {
			editActions.className = '';
		}
		editing = false;
	}
	if (editActions) {
		editActions.onsubmit = function(event) {
			event.preventDefault();
			editActions.className = 'post-form editing posting';
			editActions.querySelector('.cancel').disabled = true;
			editActions.querySelector('.save').disabled = true;

			var data = {};
			data['organization[info]'] = editor.innerHTML;
			data['authenticity_token'] = (editActions.querySelector('[name="authenticity_token"]') || {value: null}).value;

			postData(editActions.action, data, function(response) {
				if (response.error) {
					alert(response.error);
				} else {
					editor.innerHTML = response['organization[info]'];
					stopEditing();
				}
				editActions.querySelector('.cancel').disabled = false;
				editActions.querySelector('.save').disabled = false;
			}, (editActions.querySelector('[name="_method"]') || {value: 'PATCH'}).value);
		};
	} else if (createActions) {
		createActions.onsubmit = function(event) {
			event.preventDefault();
			createActions.className = 'post-form editing posting';
			createActions.querySelector('.save').disabled = true;

			data = new FormData(createActions);
			Array.prototype.forEach.call(document.querySelectorAll('.image-upload form input[type="file"]'), function(input) {
				data.append(input.name, input.files[0], input.value);
			});
			Array.prototype.forEach.call(document.querySelectorAll('[data-dlg]'), function(element) {
				var input = document.getElementById(element.dataset.dlg).querySelector('.edit-control');
				data.append(input.name, input.value);
			});
			data.append('organization[info]', editor.innerHTML);
			data.append('organization[status]', statusSelect.value);

			postData(createActions.action, data, function(response) {
				if (response.error) {
					alert(response.error);
				} else {
					stopEditing();
					window.location = response.newUrl;
				}
			}, (createActions.querySelector('[name="_method"]') || {value: 'PATCH'}).value);
		}
	}
	statusSelect.onchange = function() {
		var form = editActions || createActions;
		postData(form.action, {
				'authenticity_token': (form.querySelector('[name="authenticity_token"]') || {value: null}).value,
				'organization[status]': statusSelect.value
			}, function(response) {
			if (response.error) {
				showError(response.error);
			}
		}, (form.querySelector('[name="_method"]') || {value: 'PATCH'}).value);
	};
	Array.prototype.forEach.call(document.querySelectorAll('.editable-text'), function(element) {
		var dlg = document.getElementById(element.dataset.dlg);
		if (dlg) {
			var editControl = dlg.querySelector('.edit-control');
			var form = dlg.querySelector('form');
			function openDlg() {
				dlg.className = 'edit-dlg open';
				setTimeout(function() {
					var x = window.scrollX, y = window.scrollY;
					editControl.focus();
					editControl.setSelectionRange(0, editControl.value.length);
					window.scrollTo(x, y);
				}, 100);
			}
			function closeDlg(event) {
				dlg.className = 'edit-dlg';
				if (event) {
					event.preventDefault();
				}
			}
			element.onclick = openDlg;
			element.addEventListener('keydown', function(event) {
				if (event.keyCode == 13) {
					openDlg();
				}
				return true;
			});
			dlg.addEventListener('keydown', function(event) {
				if (event.keyCode == 27) {
					closeDlg();
				}
				return true;
			});
			dlg.querySelector('.cancel').onclick = closeDlg;
			form.onsubmit = function(event) {
				event.preventDefault();
				var data = {};
				data[editControl.name] = editControl.value;
				data['authenticity_token'] = (form.querySelector('[name="authenticity_token"]') || {value: null}).value;

				togglePosting(true);

				postData(form.action, data, function(response) {
					if (response.error) {
						showError(response.error);
					} else {
						element.innerHTML = response[editControl.name];
						togglePosting(false);
						closeDlg();
					}
				}, (form.querySelector('[name="_method"]') || {value: 'PATCH'}).value);
			}
			function togglePosting(isPosting) {
				dlg.className = 'edit-dlg open' + (isPosting ? ' posting' : '');
				dlg.querySelector('.cancel').disabled = isPosting;
				dlg.querySelector('.save').disabled = isPosting;
			}
			function showError(error) {
				togglePosting(false);
				dlg.className = 'edit-dlg open has-error';
				dlg.querySelector('.error-text').innerHTML = error;
				editControl.setSelectionRange(0, editControl.value.length);
			}
		}
	});
	var imageSetters = {
		set_banner_img: function(img) {
			document.getElementById('banner').style['background-image'] = 'url(' + img + ')';
		},
		set_logo_img: function(img) {
			document.querySelector('[for="logo-img"] img').src = img;
		}
	};
	Array.prototype.forEach.call(document.querySelectorAll('.image-upload'), function(element) {
		var fileInput = element.querySelector('input[type="file"]');
		var is_template = element.className.match(/\stemplate(\s|$)/);
		element.addEventListener('keydown', function(event) {
			if (event.keyCode == 13) {
				element.click();
			}
			return true;
		});
		fileInput.onchange = function() {
			if (window.FormData === undefined) {
				is_template || element.querySelector('form').submit();
			} else {
				var form = element.querySelector('form');
				if (is_template) {
					// this is a template, don't upload yet
					if (fileInput.files && fileInput.files[0]) {
						var reader = new FileReader();

						reader.onload = function (e) {
							imageSetters['set_' + element.attributes['for'].value.replace(/\-/g, '_')](e.target.result);
							if (!element.className.match(/\sfilled(\s|$)/)) {
								element.className += ' filled';
							}
						}

						reader.readAsDataURL(fileInput.files[0]);
					}
				} else {
					element.className += ' uploading';
					postData(form.action, new FormData(form), function(response) {
						if (response.error) {
							alert(response.error);
						} else {
							imageSetters['set_' + element.attributes['for'].value.replace(/\-/g, '_')](response[form.querySelector('[type="file"]').name]);
						}
						element.className = element.className.replace(/\s+uploading/g, '')
					}, (form.querySelector('[name="_method"]') || {value: 'POST'}).value);
				}
			}
		}
	});

	function postData(url, data, fn, method) {
		var xmlhttp = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject('Microsoft.XMLHTTP');

		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == XMLHttpRequest.DONE) {
				if (xmlhttp.status == 200) {
					fn(JSON.parse(xmlhttp.responseText));
				}
			}
		}

		xmlhttp.open(method.toUpperCase() || 'PATCH', url, true);
		xmlhttp.setRequestHeader('X-Requested-With', 'XMLHttpRequest');

		if (data instanceof FormData) {
			xmlhttp.send(data);
		} else {
			var query = [];
			for (var key in data) {
				query.push(encodeURIComponent(key) + '=' + encodeURIComponent(data[key]));
			}
			xmlhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
			xmlhttp.send(query.join('&'));
		}
	}
})();
