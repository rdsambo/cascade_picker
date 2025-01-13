library cascade_picker;

import 'package:flutter/material.dart';

final String NONE = "NONE";

class CascadePickerWidget extends StatelessWidget {
  final List<Item> items;
  final CascadeController controller;
  final String hintText;
  final String tabHintText;
  final Color tabColor;
  final double tabHeight;
  final TextStyle tabTitleStyle;
  final double itemHeight;
  final TextStyle itemTitleStyle;
  final Color itemColor;

  const CascadePickerWidget({
    required this.items,
    required this.controller,
    this.hintText = "Select",
    this.tabHintText = "Select",
    this.tabHeight = 40,
    this.tabColor = Colors.white,
    this.tabTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.itemHeight = 40,
    this.itemColor = Colors.white,
    this.itemTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
  });

  int getMaxDepth(List<Item>? items) {
    if (items == null || items.isEmpty) {
      return 0; // Nenhum nível em listas vazias ou nulas
    }

    int maxDepth = 0;

    for (var item in items) {
      // Calcula a profundidade máxima dos filhos
      int childDepth = getMaxDepth(item.children);
      // Atualiza a profundidade máxima geral
      maxDepth = (maxDepth > childDepth) ? maxDepth : childDepth;
    }

    // Adiciona 1 para contar o nível atual
    return maxDepth + 1;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller._fieldTextNotifier,
      builder: (context, fieldText, child) {

        return TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: fieldText == null || fieldText.isEmpty ? hintText : fieldText ,
            border: OutlineInputBorder(),
          ),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(0),
                ),
              ),
              builder: (context) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: CascadePicker(
                  items: items,
                  maxDepth: getMaxDepth(items),
                  hintText: hintText,
                  tabHintText: tabHintText,
                  controller: controller,
                  tabHeight: tabHeight,
                  tabColor: tabColor,
                  tabTitleStyle: tabTitleStyle,
                  itemHeight: itemHeight,
                  itemColor: itemColor,
                  itemTitleStyle: itemTitleStyle,
                ),
              ),
            ).whenComplete(() {
              controller.saveState();
            });
          },
        );
      },
    );
  }
}

typedef void NextPageCallback(Function(List<ItemSolo>) pageData, int currentPage, int selectIndex);

class CascadePicker extends StatefulWidget {
  final List<Item> items;
  final int maxDepth;
  final CascadeController controller;
  final String hintText;
  final String tabHintText;
  final Color tabColor;
  final double tabHeight;
  final TextStyle tabTitleStyle;
  final double itemHeight;
  final TextStyle itemTitleStyle;
  final Color itemColor;

  CascadePicker({
    required this.items,
    this.maxDepth = 3,
    required this.controller,
    required this.hintText,
    required this.tabHintText,
    this.tabHeight = 40,
    this.tabColor = Colors.white,
    this.tabTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
    this.itemHeight = 40,
    this.itemColor = Colors.white,
    this.itemTitleStyle = const TextStyle(color: Colors.black, fontSize: 14),
  });

  @override
  _CascadePickerState createState() => _CascadePickerState(this.controller);
}

class _CascadePickerState extends State<CascadePicker> with SingleTickerProviderStateMixin {
  final CascadeController _cascadeController;

  _CascadePickerState(this._cascadeController) {
    _cascadeController._setState(this);
  }

  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;
  Animation? _sliderAnimation;
  final _sliderFixMargin = ValueNotifier(0.0);
  double _sliderWidth = 20;

  PageController? _pageController;

  GlobalKey _sliderKey = GlobalKey();
  List<GlobalKey> _tabKeys = [];

  List<List<ItemSolo>> _pagesData = [];
  List<ItemSolo> _selectedTabs = [];
  List<int> _selectedIndexes = [-1];

  double _animTabWidth = 0;
  bool _isAddTabEvent = false;
  bool _isAnimateTextHide = false;

  bool _isClickAndMoveTab = false;
  int _currentSelectPage = 0;

  _addTab(int page, int atIndex, ItemSolo currentPageItem) {
    _loadNextPageData(page, atIndex, currentPageItem);
  }

  List<ItemSolo>? nextPageData(currentPage, selectIndex) {
    List<int>? selectedIndexes = _cascadeController.selectedIndexes;

    List<Item>? currentItems = widget.items;

    for (int level = 1; level <= currentPage; level++) {
        if (currentItems == null || currentItems.isEmpty) return [];

        int index = (level == currentPage) ? selectIndex : selectedIndexes[level - 1];

        currentItems = currentItems[index].children;
    }

    return currentItems?.map((e) => ItemSolo(id: e.id, label: e.label)).toList();
  }

  _loadNextPageData(int page, int atIndex, ItemSolo currentPageItem, {bool isUpdatePage = false}) {
    setState(() {
      List<ItemSolo>? data = nextPageData(page, atIndex);
        final nextPageDataIsEmpty = data!.isEmpty;
        if (!nextPageDataIsEmpty) {
        
          if (isUpdatePage) {
            _pagesData[page] = data;
            _selectedTabs[page] = ItemSolo(id: NONE, label: widget.tabHintText);
            _selectedIndexes[page] = -1;

            _pagesData.removeRange(page + 1, _pagesData.length);
            _selectedIndexes.removeRange(page + 1, _selectedIndexes.length);
            _selectedTabs.removeRange(page + 1, _selectedTabs.length);
          } else {
            _isAnimateTextHide = true;
            _isAddTabEvent = true;
            _pagesData.add(data);
            _selectedTabs.add(ItemSolo(id: NONE, label: widget.tabHintText));
            _selectedIndexes.add(-1);
          }
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _moveSlider(page, isAdd: true);
          });
        } else {
          final currentPage = page - 1;
          _selectedTabs[currentPage] = currentPageItem;
          _selectedIndexes[currentPage] = atIndex;

          _pagesData.removeRange(page, _pagesData.length);
          _selectedIndexes.removeRange(page, _selectedIndexes.length);
          _selectedTabs.removeRange(page, _selectedTabs.length);
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _moveSlider(currentPage);
          });
        }
      });

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
      _pageController!.animateToPage(page, curve: Curves.linear, duration: Duration(milliseconds: 500));
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
              _selectedTabs[i].label,//getLabelBySelectedIdAtLevel(i),
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
      if (i == _pagesData.length - 1 && _selectedTabs[i].id == NONE) {
        widgets.add(_animateTab(tab: tab));
        _isAnimateTextHide = false;
      } else {
        widgets.add(tab);
      }
    }
    return widgets;
  }

  Widget _pageItemWidget(int index, int page, ItemSolo item) {
    return GestureDetector(
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 15),
        height: widget.itemHeight,
        color: widget.itemColor,
        child: Row(
          children: [
            item.id == _selectedTabs[page].id
                ? Padding(
              padding: const EdgeInsets.all(5.0),
              child: Icon(Icons.chevron_right, size: 15, color: Colors.redAccent),
            )
                : SizedBox(),
            Text(
                "${item.label}",
                style: item.id == _selectedTabs[page].id
                    ? widget.itemTitleStyle.copyWith(color: Colors.redAccent)
                    : widget.itemTitleStyle
            ),
          ],
        ),
      ),
      onTap: () {
        if (page == widget.maxDepth - 1) {
          setState(() {
            _selectedTabs[page] = item;
            _selectedIndexes[page] = index;
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              _moveSlider(page);
            });
          });
        } else if (_tabKeys.length >= widget.maxDepth || page < _tabKeys.length - 1) {
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

    _selectedTabs = [ItemSolo(id: NONE, label: widget.tabHintText)];

    widget.controller.restoreState();
    _pageController = PageController(initialPage: _cascadeController.selectedIndexes.length);

    if (widget.controller.isFirstInteraction) {
      _pagesData.add(widget.items.map<ItemSolo>((e) => ItemSolo(id: e.id, label: e.label)).toList());
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
                color: const Color.fromARGB(255, 200, 203, 212),
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

class Item {
  String id;
  String label;
  List<Item>? children;

  Item({required this.id, required this.label, this.children});
}
class ItemSolo {
  String id;
  String label;

  ItemSolo({required this.id, required this.label});
}

class CascadeController  extends ChangeNotifier {
  _CascadePickerState? _state;

  bool isFirstInteraction = true;
  List<ItemSolo>? _savedSelectedTabs;
  List<int>? _savedSelectedIndexes;
  List<List<ItemSolo>>? _savedPagesData;

  final ValueNotifier<String> _fieldTextNotifier =
      ValueNotifier<String>('');

  void _setState(_CascadePickerState state) {
    // print('hintText $hintText');
    _state = state;
  }

  void saveState() {
    isFirstInteraction = false;
    if (_state != null) {
      _savedSelectedTabs = List<ItemSolo>.from(_state!._selectedTabs);
      _savedSelectedIndexes = List<int>.from(_state!._selectedIndexes);
      _savedPagesData = List<List<ItemSolo>>.from(_state!._pagesData);

      _updateSelectedTiles();
    }
  }

  void _updateSelectedTiles() {
    _fieldTextNotifier.value = isCompleted
      ? _state?._selectedTabs.map((e) => e.label).join(' > ') ?? _state!.widget.hintText
      : _state!.widget.hintText;

    notifyListeners();
  }

  void restoreState() {
    if (_state != null && _savedSelectedTabs != null && _savedSelectedIndexes != null && _savedPagesData != null) {
      _state!._selectedTabs = List<ItemSolo>.from(_savedSelectedTabs!);
      _state!._selectedIndexes = List<int>.from(_savedSelectedIndexes!);
      _state!._pagesData = List<List<ItemSolo>>.from(_savedPagesData!);
    }
  }

  String get fieldText => _fieldTextNotifier.value;
  List<ItemSolo> get selectedTitles => _state?._selectedTabs  ?? [];
  List<int> get selectedIndexes => _state?._selectedIndexes ?? [];
  bool get isCompleted => !(_state?._selectedTabs.map((e) => e.label).contains(_state!.widget.tabHintText) ?? true);
}
