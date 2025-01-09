library cascade_picker;

import 'package:flutter/material.dart';

class CascadePickerWidget extends StatelessWidget {
  final List<String> initialPageData;
  final NextPageCallback nextPageData;
  final int maxPageNum;
  final CascadeController controller;
  final Color tabColor;
  final double tabHeight;
  final TextStyle tabTitleStyle;
  final double itemHeight;
  final TextStyle itemTitleStyle;
  final Color itemColor;
  final Widget? selectedIcon;

  const CascadePickerWidget({
    required this.initialPageData,
    required this.nextPageData,
    this.maxPageNum = 3,
    required this.controller,
    this.tabHeight = 40,
    this.tabColor = Colors.white,
    this.tabTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.itemHeight = 40,
    this.itemColor = Colors.white,
    this.itemTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.8, // Configura a altura do modal
            child: CascadePicker(
              initialPageData: initialPageData,
              nextPageData: nextPageData,
              maxPageNum: maxPageNum,
              controller: controller,
              tabHeight: tabHeight,
              tabColor: tabColor,
              tabTitleStyle: tabTitleStyle,
              itemHeight: itemHeight,
              itemColor: itemColor,
              itemTitleStyle: itemTitleStyle,
              selectedIcon: selectedIcon,
            ),
          ),
        ).whenComplete(() {
          controller.saveState(); // Salva o estado ao fechar o modal
        });
      },
      child: const Text('Open Cascade Picker'),
    );
  }
}

typedef void NextPageCallback(Function(List<String>) pageData, int currentPage, int selectIndex);

class CascadePicker extends StatefulWidget {

  final List<String> initialPageData;
  final NextPageCallback nextPageData;
  final int maxPageNum;
  final CascadeController controller;
  final Color tabColor;
  final double tabHeight;
  final TextStyle tabTitleStyle;
  final double itemHeight;
  final TextStyle itemTitleStyle;
  final Color itemColor;
  final Widget? selectedIcon;

  CascadePicker({
    required this.initialPageData,
    required this.nextPageData,
    this.maxPageNum = 3,
    required this.controller,
    this.tabHeight = 40,
    this.tabColor = Colors.white,
    this.tabTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.itemHeight = 40,
    this.itemColor = Colors.white,
    this.itemTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.selectedIcon
  });

  @override
  _CascadePickerState createState() => _CascadePickerState(this.controller);
}

class _CascadePickerState extends State<CascadePicker> with SingleTickerProviderStateMixin {

  static String _newTabName = "Select";

  final CascadeController _cascadeController;

  _CascadePickerState(this._cascadeController) {
    _cascadeController._setState(this);
  }

  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;
  Animation? _sliderAnimation;
  final _sliderFixMargin = ValueNotifier(0.0);
  double _sliderWidth = 20;

  PageController _pageController = PageController(initialPage: 0);

  GlobalKey _sliderKey = GlobalKey();
  List<GlobalKey> _tabKeys = [];

  List<List<String>> _pagesData = [];
  List<String> _selectedTabs = [_newTabName];
  List<int> _selectedIndexes = [-1];

  double _animTabWidth = 0;
  bool _isAddTabEvent = false;
  bool _isAnimateTextHide = false;

  bool _isClickAndMoveTab = false;
  int _currentSelectPage = 0;

  _addTab(int page, int atIndex, String currentPageItem) {
    _loadNextPageData(page, atIndex, currentPageItem);
  }

  _loadNextPageData(int page, int atIndex, String currentPageItem, {bool isUpdatePage = false}) {
    widget.nextPageData((data) {
      final nextPageDataIsEmpty = data.isEmpty;
      if (!nextPageDataIsEmpty) {

        setState(() {
          if (isUpdatePage) {

            _pagesData[page] = data;
            _selectedTabs[page] = _newTabName;
            _selectedIndexes[page] = -1;

            _pagesData.removeRange(page + 1, _pagesData.length);
            _selectedIndexes.removeRange(page + 1, _selectedIndexes.length);
            _selectedTabs.removeRange(page + 1, _selectedTabs.length);
          } else {

            _isAnimateTextHide = true;
            _isAddTabEvent = true;
            _pagesData.add(data);
            _selectedTabs.add(_newTabName);
            _selectedIndexes.add(-1);
          }
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _moveSlider(page, isAdd: true);
          });
        });
      } else {

        final currentPage = page - 1;
        setState(() {
          _selectedTabs[currentPage] = currentPageItem;
          _selectedIndexes[currentPage] = atIndex;

          _pagesData.removeRange(page, _pagesData.length);
          _selectedIndexes.removeRange(page, _selectedIndexes.length);
          _selectedTabs.removeRange(page, _selectedTabs.length);
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {

            _moveSlider(currentPage);
          });
        });
      }
    }, page, atIndex);
  }

  _moveSlider(int page, {bool movePage = true, bool isAdd = false}) {
    if (movePage && _currentSelectPage != page) {
      _isClickAndMoveTab = true;
    }
    _isAddTabEvent = isAdd;
    _currentSelectPage = page;

    if (_controller.isAnimating) {
      _controller.stop();
    }
    RenderBox slider = _sliderKey.currentContext?.findRenderObject() as RenderBox;
    Offset sliderPosition = slider.localToGlobal(Offset.zero);
    RenderBox currentTabBox = _tabKeys[page].currentContext?.findRenderObject() as RenderBox;
    Offset currentTabPosition = currentTabBox.localToGlobal(Offset.zero);

    _animTabWidth = currentTabBox.size.width;

    final begin = sliderPosition.dx - _sliderFixMargin.value;
    final end = currentTabPosition.dx + (currentTabBox.size.width - _sliderWidth) / 2 - _sliderFixMargin.value;
    _sliderAnimation = Tween<double>(begin: begin, end: end).animate(_curvedAnimation);
    _controller.value = 0;
    _controller.forward();
    if (movePage) {
      _pageController.animateToPage(page, curve: Curves.linear, duration: Duration(milliseconds: 500));
    }
  }

  Widget _animateTab({required Widget tab}) {
    return Transform.translate(
      offset: Offset(Tween<double>(begin: _isAddTabEvent ? -_animTabWidth : 0, end: 0).evaluate(_curvedAnimation), 0),
      child: Opacity(
          opacity: _isAnimateTextHide ? 0 : 1,
          child: tab
      ),
    );
  }

  List<Widget> _tabWidgets() {
    List<Widget> widgets = [];
    _tabKeys.clear();
    for (int i = 0; i < _pagesData.length; i++) {
      GlobalKey key = GlobalKey();
      _tabKeys.add(key);
      final tab = GestureDetector(
        child: Container(
          key: key,
          height: widget.tabHeight,
          color: widget.tabColor,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width / _pagesData.length - 10),
            child: Text(
              _selectedTabs[i],
              style: _currentSelectPage == i ? widget.tabTitleStyle.copyWith(color: Colors.redAccent) : widget.tabTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        onTap: () {
          _moveSlider(i);
        },
      );
      if (i == _pagesData.length - 1 && _selectedTabs[i] == _newTabName) {
        widgets.add(_animateTab(tab: tab));
        _isAnimateTextHide = false;
      } else {
        widgets.add(tab);
      }
    }
    return widgets;
  }

  Widget _pageItemWidget(int index, int page, String item) {
    return GestureDetector(
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 15),
        height: widget.itemHeight,
        color: widget.itemColor,
        child: Row(
          children: [
            item == _selectedTabs[page]
                ? Padding(
              padding: const EdgeInsets.all(5.0),
              child: widget.selectedIcon == null
                  ? Icon(Icons.chevron_right, size: 15, color: Colors.redAccent)
                  : widget.selectedIcon,
            )
                : SizedBox(),
            Text(
                "$item",
                style: item == _selectedTabs[page]
                    ? widget.itemTitleStyle.copyWith(color: Colors.redAccent)
                    : widget.itemTitleStyle
            ),
          ],
        ),
      ),
      onTap: () {
        if (page == widget.maxPageNum - 1) {
          setState(() {
            _selectedTabs[page] = item;
            _selectedIndexes[page] = index;
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              _moveSlider(page);
            });
          });
        } else if (_tabKeys.length >= widget.maxPageNum || page < _tabKeys.length - 1) {
          if (index == _selectedIndexes[page]) {
            _moveSlider(page + 1);
          } else {
            setState(() {
              _selectedTabs[page] = item;
              _selectedIndexes[page] = index;
            });
            _loadNextPageData(page + 1, index, item, isUpdatePage: true);
          }
        } else {
          _selectedTabs[page] = item;
          _selectedIndexes[page] = index;
          _addTab(page + 1, index, item);
        }
      },
    );
  }

  Widget _pageWidget(int page) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _pagesData[page].length,
      itemBuilder: (context, index) => _pageItemWidget(index, page, _pagesData[page][index]),
//      separatorBuilder: (context, index) => Divider(height: 0.3, thickness: 0.3, color: Color(0xffdddddd), indent: 15, endIndent: 15,),
    );
  }

  @override
  void initState() {
    super.initState();

    widget.controller.restoreState();

    if (widget.controller.isFirstInteraction) {
      _pagesData.add(widget.initialPageData);
    }

    _controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this
    );

    _curvedAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.ease
    )..addStatusListener((state) {
    });

    _sliderAnimation = Tween<double>(begin: 0, end: 10).animate(_curvedAnimation);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      RenderBox tabBox = _tabKeys.first.currentContext?.findRenderObject() as RenderBox;
      _sliderFixMargin.value = (tabBox.size.width - _sliderWidth) / 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _sliderAnimation!,
          builder: (context, child) => Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                child: Row(
                  children: _tabWidgets(),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: _sliderFixMargin,
                builder: (_, margin, __) => Positioned(
                  left: margin + _sliderAnimation!.value,
                  child: Container(
                    key: _sliderKey,
                    width: _sliderWidth,
                    height: 2,
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            itemCount: _pagesData.length,
            controller: _pageController,
            itemBuilder: (context, index) => _pageWidget(index),
            onPageChanged: (position) {
              if (!_isClickAndMoveTab) {
                _moveSlider(position, movePage: false);
              }
              if (_currentSelectPage == position) {
                _isClickAndMoveTab = false;
              }
            },
          ),
        )
      ],
    );
  }
}

class CascadeController {
  _CascadePickerState? _state;

  bool isFirstInteraction = true;
  List<String>? _savedSelectedTabs;
  List<int>? _savedSelectedIndexes;
  List<List<String>>? _savedPagesData;

  void _setState(_CascadePickerState state) {
    _state = state;
  }

  void saveState() {
    isFirstInteraction = false;
    if (_state != null) {
      _savedSelectedTabs = List<String>.from(_state!._selectedTabs);
      _savedSelectedIndexes = List<int>.from(_state!._selectedIndexes);
      _savedPagesData = List<List<String>>.from(_state!._pagesData);
    }
  }

  void restoreState() {
    if (_state != null && _savedSelectedTabs != null && _savedSelectedIndexes != null && _savedPagesData != null) {
      _state!._selectedTabs = List<String>.from(_savedSelectedTabs!);
      _state!._selectedIndexes = List<int>.from(_savedSelectedIndexes!);
      _state!._pagesData = List<List<String>>.from(_savedPagesData!);
    }
  }

  List<String> get selectedTitles => _state!._selectedTabs;
  List<int> get selectedIndexes => _state!._selectedIndexes;
  bool isCompleted() => !_state!._selectedTabs.contains(_CascadePickerState._newTabName);
}