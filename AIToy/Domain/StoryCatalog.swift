import Foundation

struct StoryCatalog: Sendable {
    let stories: [StoryLesson]

    static let sample = StoryCatalog(stories: [.birthdayCakeAdventure])
}

extension StoryLesson {
    static let birthdayCakeAdventure = StoryLesson(
        id: "choochoo-birthday-cake",
        title: "啾啾的生日蛋糕",
        subtitle: "啾啾和朋友们准备生日惊喜",
        difficulty: .general,
        estimatedMinutes: 7,
        coverEmoji: "🎂",
        themeColors: ["F3A8BE", "F9D7E2", "D8B5D4"],
        beats: [
            StoryBeat(
                id: "choose-helper",
                title: "谁会做蛋糕？",
                illustrationEmoji: "🦊",
                narration: "今天是猫咪妙妙的生日。小龙啾啾想送她一个特别的惊喜：亲手做一个香香的生日蛋糕。可是，啾啾从来没有烤过蛋糕。他想起三个好朋友：小马燕丽最爱唱歌，盼盼喜欢开车去远方，小狐狸菲菲常常在厨房里做面包和蛋糕。啾啾认真想了想，决定先请最懂烘焙的朋友来帮忙。",
                englishNarration: "Today was Miaomiao the cat's birthday. ChooChoo wanted to surprise her with a homemade birthday cake, but he had never baked one before. He thought of three friends: Yanli the pony loved singing, Panpan liked driving, and Feifei the little fox often made bread and cakes. ChooChoo decided to ask the friend who knew baking best for help.",
                narrationCueID: "scene_choose_helper",
                checkpoint: StoryCheckpoint(
                    id: "fox-bakes",
                    question: "三个朋友里，谁最会做蛋糕？",
                    englishQuestion: "Which of the three friends was best at making cakes?",
                    questionCueID: "question_fox_bakes",
                    requiredConcepts: [
                        AnswerConcept(id: "fox", chineseTerms: ["小狐狸", "狐狸", "菲菲", "小狐狸菲菲"], englishTerms: ["little fox", "fox", "feifei"], homophones: ["小湖里", "飞飞", "菲菲狐狸"])
                    ],
                    relatedTerms: ["做蛋糕", "烤蛋糕", "烘焙", "厨房", "朋友"],
                    knownWrongTerms: ["燕丽", "小马", "盼盼", "妙妙"],
                    recast: "小狐狸菲菲最会做蛋糕。",
                    successMessage: "答对了！小狐狸菲菲最会烘焙，啾啾请她来帮忙。",
                    minimalEnglishHint: "Think about the friend who often bakes.",
                    reviewVocabulary: [
                        VocabularyItem(id: "little-fox", chinese: "小狐狸", pinyin: "xiǎo hú li", english: "little fox"),
                        VocabularyItem(id: "bake-cake", chinese: "做蛋糕", pinyin: "zuò dàn gāo", english: "make a cake")
                    ],
                    hints: [
                        HintStep(id: "helper-h1", level: 1, text: "这个朋友常常在厨房里烤面包。她是谁？", cueID: "helper_hint_1"),
                        HintStep(id: "helper-h2", level: 2, text: "请填空：最会做蛋糕的是小——。", cueID: "helper_hint_2"),
                        HintStep(id: "helper-h3", level: 3, text: "The little fox loves baking. 你可以说：小狐狸……", cueID: "helper_hint_3"),
                        HintStep(id: "helper-h4", level: 4, text: "请选择：是小狐狸，还是小马？请说完整：小狐狸最会做蛋糕。", cueID: "helper_hint_4")
                    ]
                )
            ),
            StoryBeat(
                id: "gather-ingredients",
                title: "红红的草莓",
                illustrationEmoji: "🍓",
                narration: "小狐狸菲菲来到啾啾家，写下一张材料清单：面粉、鸡蛋、牛奶，还有妙妙最喜欢的草莓。大家分头准备。啾啾抱来面粉，燕丽小心地提来一篮鸡蛋。盼盼开着黄色小车去了果园，回来时车厢里装满了红红的草莓。朋友们把材料摆在桌上，一样一样对照清单，什么都没有忘记。",
                englishNarration: "Feifei came to ChooChoo's home and wrote a list: flour, eggs, milk, and Miaomiao's favorite strawberries. Everyone helped. ChooChoo brought flour, Yanli carried a basket of eggs, and Panpan drove a yellow car to the orchard. Panpan returned with the car full of bright red strawberries. The friends checked every item and forgot nothing.",
                narrationCueID: "scene_gather_ingredients",
                checkpoint: StoryCheckpoint(
                    id: "panpan-strawberries",
                    question: "盼盼开车带回来了什么？",
                    englishQuestion: "What did Panpan bring back in the car?",
                    questionCueID: "question_panpan_strawberries",
                    requiredConcepts: [
                        AnswerConcept(id: "strawberries", chineseTerms: ["草莓", "红草莓", "一车草莓", "红红的草莓"], englishTerms: ["strawberry", "strawberries"], homophones: ["草梅", "草没"])
                    ],
                    relatedTerms: ["果园", "黄色小车", "水果", "材料", "车厢"],
                    knownWrongTerms: ["面粉", "鸡蛋", "牛奶", "苹果"],
                    recast: "盼盼开车带回来一车红红的草莓。",
                    successMessage: "没错！盼盼从果园带回了妙妙最喜欢的草莓。",
                    minimalEnglishHint: "It is a small red fruit.",
                    reviewVocabulary: [
                        VocabularyItem(id: "strawberry", chinese: "草莓", pinyin: "cǎo méi", english: "strawberry"),
                        VocabularyItem(id: "bring-back", chinese: "带回来", pinyin: "dài huí lái", english: "bring back")
                    ],
                    hints: [
                        HintStep(id: "berries-h1", level: 1, text: "这种水果红红的，表面有许多小点点。", cueID: "berries_hint_1"),
                        HintStep(id: "berries-h2", level: 2, text: "请填空：盼盼带回来一车草——。", cueID: "berries_hint_2"),
                        HintStep(id: "berries-h3", level: 3, text: "Pan Pan brought strawberries. 你可以说：盼盼带回了……", cueID: "berries_hint_3"),
                        HintStep(id: "berries-h4", level: 4, text: "请选择：盼盼带回草莓，还是面粉？请说完整答案。", cueID: "berries_hint_4")
                    ]
                )
            ),
            StoryBeat(
                id: "mix-together",
                title: "太稠的面糊",
                illustrationEmoji: "🥣",
                narration: "菲菲把面粉和鸡蛋倒进大碗，啾啾用木勺搅呀搅。可是面糊越来越稠，木勺差点拔不出来。燕丽看了看清单，说还少了牛奶。她慢慢把牛奶倒进碗里，啾啾继续搅拌。一个倒牛奶，一个搅面糊，两个人配合得刚刚好。面糊终于变得又滑又香，菲菲把它放进烤箱。",
                englishNarration: "Feifei poured flour and eggs into a large bowl while ChooChoo stirred with a wooden spoon. The batter became so thick that the spoon almost got stuck. Yanli checked the list and noticed they still needed milk. She slowly poured milk into the bowl while ChooChoo kept stirring. Working together made the batter smooth and ready for the oven.",
                narrationCueID: "scene_mix_together",
                checkpoint: StoryCheckpoint(
                    id: "milk-and-stir",
                    question: "面糊太稠时，燕丽和啾啾一起做了什么？",
                    englishQuestion: "What did Yanli and ChooChoo do when the batter was too thick?",
                    questionCueID: "question_milk_and_stir",
                    requiredConcepts: [
                        AnswerConcept(id: "milk", chineseTerms: ["倒牛奶", "倒了牛奶", "加牛奶", "加了牛奶", "放牛奶", "牛奶倒进去"], englishTerms: ["add milk", "pour milk", "milk"], homophones: ["到牛奶", "倒奶"]),
                        AnswerConcept(id: "stir", chineseTerms: ["搅拌", "搅面糊", "用木勺搅", "继续搅"], englishTerms: ["stir", "mix", "mix the batter"], homophones: ["脚拌", "搅伴"])
                    ],
                    relatedTerms: ["面糊", "大碗", "木勺", "一起", "合作"],
                    knownWrongTerms: ["加水", "扔掉", "不做了", "直接吃"],
                    recast: "燕丽倒牛奶，啾啾继续搅拌面糊。",
                    successMessage: "说得很好！燕丽加牛奶，啾啾搅面糊，他们合作解决了问题。",
                    minimalEnglishHint: "One friend used milk, and the other used a spoon.",
                    reviewVocabulary: [
                        VocabularyItem(id: "pour-milk", chinese: "倒牛奶", pinyin: "dào niú nǎi", english: "pour milk"),
                        VocabularyItem(id: "stir", chinese: "搅拌", pinyin: "jiǎo bàn", english: "stir")
                    ],
                    hints: [
                        HintStep(id: "mix-h1", level: 1, text: "燕丽拿着牛奶，啾啾拿着木勺。想想他们各自做了什么。", cueID: "mix_hint_1"),
                        HintStep(id: "mix-h2", level: 2, text: "请填空：燕丽倒牛奶，啾啾继续——面糊。", cueID: "mix_hint_2"),
                        HintStep(id: "mix-h3", level: 3, text: "Yan Li poured milk, and ChooChoo stirred. 你可以说：燕丽……啾啾……", cueID: "mix_hint_3"),
                        HintStep(id: "mix-h4", level: 4, text: "请选择：他们加牛奶并搅拌，还是把面糊扔掉？请说完整答案。", cueID: "mix_hint_4")
                    ]
                )
            ),
            StoryBeat(
                id: "birthday-surprise",
                title: "一起唱生日歌",
                illustrationEmoji: "🎂",
                narration: "蛋糕烤好了，菲菲在上面摆出一圈草莓。盼盼关上灯，燕丽轻轻弹起生日歌，大家躲在桌子后面。妙妙推门进来时，啾啾点亮小蜡烛，朋友们一起跳出来唱生日快乐。妙妙惊喜得眼睛亮亮的。她许下愿望，然后把蛋糕分给每一个朋友。啾啾觉得，最甜的不只是蛋糕，还有大家一起准备惊喜的心意。",
                englishNarration: "The cake was ready, and Feifei decorated it with strawberries. Panpan turned off the lights, Yanli began the birthday music, and everyone hid behind the table. When Miaomiao opened the door, ChooChoo lit the candles and the friends jumped out to sing Happy Birthday. Miaomiao made a wish and shared the cake with everyone. The sweetest part was the care they put into the surprise together.",
                narrationCueID: "scene_birthday_surprise",
                checkpoint: StoryCheckpoint(
                    id: "sing-for-maomiao",
                    question: "妙妙进门时，朋友们怎样为她庆祝生日？",
                    englishQuestion: "How did the friends celebrate when Miaomiao came in?",
                    questionCueID: "question_sing_for_maomiao",
                    requiredConcepts: [
                        AnswerConcept(id: "birthday-song", chineseTerms: ["唱生日歌", "唱生日快乐", "唱歌祝她生日快乐", "一起唱歌"], englishTerms: ["sing happy birthday", "birthday song", "sang to her"], homophones: ["唱生日哥", "生日割"])
                    ],
                    relatedTerms: ["惊喜", "蜡烛", "关灯", "蛋糕", "庆祝"],
                    knownWrongTerms: ["睡觉", "离开", "藏起蛋糕", "开车回家"],
                    recast: "朋友们一起为妙妙唱生日快乐。",
                    successMessage: "完全正确！大家一起唱生日歌，把准备好的惊喜送给妙妙。",
                    minimalEnglishHint: "They used music and their voices.",
                    reviewVocabulary: [
                        VocabularyItem(id: "birthday-song", chinese: "生日歌", pinyin: "shēng rì gē", english: "birthday song"),
                        VocabularyItem(id: "celebrate", chinese: "庆祝", pinyin: "qìng zhù", english: "celebrate")
                    ],
                    hints: [
                        HintStep(id: "party-h1", level: 1, text: "燕丽弹起音乐，大家张开嘴巴一起做什么？", cueID: "party_hint_1"),
                        HintStep(id: "party-h2", level: 2, text: "请填空：朋友们一起唱生——歌。", cueID: "party_hint_2"),
                        HintStep(id: "party-h3", level: 3, text: "They sang Happy Birthday. 你可以说：朋友们一起……", cueID: "party_hint_3"),
                        HintStep(id: "party-h4", level: 4, text: "请选择：大家唱生日歌，还是开车回家？请说完整答案。", cueID: "party_hint_4")
                    ]
                )
            )
        ]
    )
}
