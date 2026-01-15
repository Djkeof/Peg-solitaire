实现2D像素风格Peg solitaire游戏

游戏规则：

游戏玩法似中国跳棋，但不能走步，只能跳。棋子只能跳过相邻的棋子到空位上，并且把被跳过的棋子吃掉。棋子可以沿格线横、纵方向跳，但是不能斜跳，剩下越少棋子越好。

评级：

最后剩下6只或以上棋子是“一般”；最后剩下5只棋子是“颇好”；剩下4只棋子是“很好”；剩下3只棋子是“聪明”；剩下2只棋子是“尖子”；剩下1只棋子是“大师”；最后剩下1只，而且在正中央是“天才”。

棋子动画：

棋子使用小猫素材F:\Godot\peg_solitaire\Peg_solitaire_assets\cat，棋子静态时显示idle，跳动时显示jump或run。

棋盘动画：

使用英式33棋盘。

背景音乐：

使用鸟鸣声F:\Godot\peg_solitaire\assets\sound\backgroung.mp3。

音效：

点击棋子使用猫叫声F:\Godot\peg_solitaire\assets\sound\cat-meow.wav。
无效移动/错误使用猫叫声F:\Godot\peg_solitaire\assets\sound\cat-hissing.wav。