using System;
using System.Collections;
using System.Reflection;
using Serialize.Util;

namespace Serialize
{
	[AttributeUsage(.Types)]
	struct SerializableAttribute : Attribute, IOnTypeInit
	{
		public String Tag;

		[Comptime]
		bool IsSerializableField(FieldInfo field)
		{
			let type = field.FieldType;

			if (type.IsPointer)
				return false;

			if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr))
				return attr.Serialize && !attr.Flatten;

			if (field.IsStatic || field.IsConst || field.IsPrivate)
				return false;

			return true;
		}

		[Comptime]
		void IOnTypeInit.OnTypeInit(Type type, Self* prev)
		{
			Compiler.EmitAddInterface(type, typeof(ISerializable));

			if (type.IsEnum)
			{
				if (type.IsUnion)
					WriteSerializeInnerTypeEnum(type);

				WriteSerializeForEnum(type);
				return;
			}

			FieldInfo? flatField = null;
			Type flatValueType = null;
			int fieldCount = 0;
			for (let field in type.GetFields())
			{
				if (IsSerializableField(field))
					fieldCount++;
				else if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr))
				{
					if (attr.Flatten)
					{
						Runtime.Assert(flatField == null, "Serializable can only have one flat field");

						flatField = field;
						flatValueType = (field.FieldType as SpecializedGenericType).GetGenericArg(1);
					}
				}
			}

			Compiler.EmitTypeBody(type,
				scope $"""
				public void Serialize<S>(S serializer)
					where S : Serialize.Implementation.ISerializer
				{{
					serializer.SerializeMapStart({fieldCount});

					switch (serializer.SerializeOrder)
					{{
					case .InOrder:
						{{

				""");

			WriteSerializeInOrder(type);

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					case .PrimitivesArraysMaps:
						{{

				""");

			WriteSerializePrimitivesArraysMaps(type, flatField, flatValueType);
			
			String fieldList = scope .();
			bool f = true;
			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				if (!f)
					fieldList.Append(", ");
				fieldList.AppendF("\"{}\"", SerializedName(field));
				f = false;
			}

			Compiler.EmitTypeBody(type,
				scope $"""
				
					serializer.SerializeMapEnd();
				}}

				public static System.Result<Self> Deserialize<S>(S deserializer)
					where S : Serialize.Implementation.IDeserializer
				{{
					Self self = {(type.IsValueType ? "" : "new ")}Self();
					bool ok = false;
					{(type.IsValueType ? "" : "defer {{ if (!ok) delete self; }}\n")}
					System.Collections.List<System.StringView> fieldsLeft = scope .(){{ {fieldList} }};

					Try!(deserializer.DeserializeStructStart({fieldCount}));

					delegate System.Result<void, Serialize.FieldDeserializeError>(System.StringView) mapField = scope [&] (field) => {{
						switch (field)
						{{

				""");

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				let fieldSerName = SerializedName(field);

				if (field.FieldType.IsNullable || field.FieldType.IsObject)
				{
					Compiler.EmitTypeBody(type,
						scope $"""
								case "{fieldSerName}":
									System.Diagnostics.Debug.Assert(fieldsLeft.Contains("{fieldSerName}"));

									if (!deserializer.DeserializeNull())
									{{
										let result = {field.FieldType}.Deserialize(deserializer);
										if (result case .Err)
											return .Err(.DeserializationError);
										self.{field.Name} = result.Get();
									}}
									fieldsLeft.Remove("{fieldSerName}");
									break;
	
						""");
				}
				else
				{
					Compiler.EmitTypeBody(type,
					scope $"""
							case "{fieldSerName}":
								System.Diagnostics.Debug.Assert(fieldsLeft.Contains("{fieldSerName}"));

								let result = {field.FieldType}.Deserialize(deserializer);
								if (result case .Err)
									return .Err(.DeserializationError);
								self.{field.Name} = (.)result.Get();
								fieldsLeft.Remove("{fieldSerName}");
								break;

					""");
				}
			}

			if (flatField != null)
			{
				let flat = flatField.Value;
				let valueType = (flat.FieldType as SpecializedGenericType).GetGenericArg(1);
				if (valueType.IsNullable || valueType.IsObject)
				{
					Compiler.EmitTypeBody(type,
						scope $"""
								default:
									System.Diagnostics.Debug.Assert(self.{flat.Name} == null || !self.{flat.Name}.ContainsKeyAlt(field));

									if (!deserializer.DeserializeNull())
									{{
										let result = {valueType}.Deserialize(deserializer);
										if (result case .Err)
											return .Err(.DeserializationError);
										if (self.{flat.Name} == null)
											self.{flat.Name} = new .();
										self.{flat.Name}[new .(field)] = result.Get();
									}}
									else
									{{
										self.{flat.Name}[new .(field)] = null;
									}}
						""");
				}
				else
				{
					Compiler.EmitTypeBody(type,
					scope $"""
							default:
								System.Diagnostics.Debug.Assert(self.{flat.Name} == null || !self.{flat.Name}.ContainsKeyAlt(field));

								let result = {valueType}.Deserialize(deserializer);
								if (result case .Err)
									return .Err(.DeserializationError);

								if (self.{flat.Name} == null)
									self.{flat.Name} = new .();
								self.{flat.Name}[new .(field)] = (.)result.Get();
					""");
				}
			}
			else
			{
				Compiler.EmitTypeBody(type,
					"""
							default:
								return .Err(.UnknownField);
					""");
			}

			Compiler.EmitTypeBody(type,
				scope $"""
							
						}}

						return .Ok;
					}};

					bool firstField = true;

				""");

			if (flatField != null)
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						int readFieldCount = {fieldCount};
						FieldLoop: for (int _ <= readFieldCount)
						{{
							if (deserializer.DeserializeStructField(mapField, fieldsLeft, firstField) case .Err(let err))
							{{
								switch (err)
								{{
								case .UnknownField: break FieldLoop;
								case .DeserializationError: return .Err;
								}}
							}}
							
							readFieldCount = {fieldCount} + (self.{flatField?.Name}?.Count ?? 0);
							firstField = false;
						}}


					""");
			}
			else
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						for (int _ < {fieldCount})
						{{
							Try!(deserializer.DeserializeStructField(mapField, fieldsLeft, firstField));
							firstField = false;
						}}


					""");
			}

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				let fieldSerName = SerializedName(field);
				if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr))
				{
					if (attr.Default != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (fieldsLeft.Contains("{fieldSerName}"))
									self.{field.Name} = {attr.Default}();


							""");
					}
					else if (attr.DefaultValue != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (fieldsLeft.Contains("{fieldSerName}"))
									self.{field.Name} = {attr.DefaultValue};


							""");
					}
				}
			}

			for (let field in type.GetFields())
			{
				if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr) && attr.Flatten)
				{
					if (attr.Default != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (self.{field.Name} == null)
									self.{field.Name} = {attr.Default}();


							""");
					}
					else if (attr.DefaultValue != null)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								if (self.{field.Name} == null)
									self.{field.Name} = {attr.DefaultValue};


							""");
					}
				}
			}

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;


				if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr))
				{
					if (attr.Optional)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								fieldsLeft.Remove("{SerializedName(field)}");

							""");
					}
				}
			}	

			Compiler.EmitTypeBody(type,
				scope $"""
					if (!fieldsLeft.IsEmpty)
					{{
						System.String message = new .();
						if (fieldsLeft.Count == 1)
							message.Append("Missing field ");
						else
							message.Append("Missing fields ");

						bool first = true;
						for (System.StringView field in fieldsLeft)
						{{
							if (!first)
								message.Append(", ");
							message.Append(field);
							first = false;
						}}

						message.Append(" on type {type.GetName(.. scope .())}");

						deserializer.SetError(new .(message, deserializer));
						return .Err;
					}}

					Try!(deserializer.DeserializeStructEnd());
					ok = true;
					return .Ok(self);
				}}
				""");
		}

		[Comptime]
		void WriteSerializeForField(Type type, FieldInfo field, ref String first)
		{
			if (!IsSerializableField(field))
				return;

			let fieldSerName = SerializedName(field);

			let serializeAttribute = field.GetCustomAttribute<SerializeAttribute>();
			if (serializeAttribute case .Ok(let attr))
			{
				if (attr.NumberFormat != null)
					Compiler.EmitTypeBody(type,
						scope $"""
	
									serializer.NumberFormat = "{attr.NumberFormat}";
						""");
			}

			if (field.FieldType.IsNullable || field.FieldType.IsObject)
			{
				Compiler.EmitTypeBody(type,
					scope $"""

								//if (this.{field.Name} == null) serializer.SerializeNull();
								/*else*/ serializer.SerializeMapEntry("{fieldSerName}", this.{field.Name}, {first});

					""");
			}
			else
			{
//				if (serializeAttribute case .Ok(let attr) && attr.DefaultValue != null)
//				{
//					Compiler.EmitTypeBody(type,
//						scope $"""
//
//									if (this.{field.Name} != {attr.DefaultValue})
//						    
//						""");
//				}

				Compiler.EmitTypeBody(type,
				scope $"""
							serializer.SerializeMapEntry("{fieldSerName}", this.{field.Name}, {first});

				""");
			}

			if (serializeAttribute case .Ok(let attr))
			{
				if (attr.NumberFormat != null)
					Compiler.EmitTypeBody(type,
						scope $"""
									serializer.NumberFormat = "";

						""");
			}

			first = "false";
		}

		[Comptime]
		void WriteSerializeInOrder(Type type)
		{
			String first = "true";
			for (let field in type.GetFields())
			{
				WriteSerializeForField(type, field, ref first);
				first = "false";
			}
		}

		[Comptime]
		void WriteSerializePrimitivesArraysMaps(Type type, FieldInfo? flatField, Type flatValueType)
		{
			String first = "true";
			List<FieldInfo> primitives = scope .();
			List<FieldInfo> arrays = scope .();
			List<FieldInfo> maps = scope .();

			for (let field in type.GetFields())
			{
				if (!IsSerializableField(field))
					continue;

				if (Util.IsPrimitive(field.FieldType))
					primitives.Add(field);
				else if (Util.IsList(field.FieldType))
					arrays.Add(field);
				else
					maps.Add(field);
			}

			for (let field in primitives)
				WriteSerializeForField(type, field, ref first);

			if (flatField != null)
			{
				let flat = flatField.Value;
				if (flatValueType == typeof(Variant))
				{
					if (primitives.IsEmpty)
					{
						first = "first";
						Compiler.EmitTypeBody(type,
							scope $"""
										bool hasOtherFields = this.{flat.Name} != null && !this.{flat.Name}.IsEmpty;
										bool first = {(primitives.IsEmpty ? "true" : "false")};
										if (hasOtherFields)
										{{
											for (let (key, value) in this.{flat.Name})
											{{
												if (Serialize.Util.Util.IsPrimitive(value.VariantType))
												{{
													serializer.SerializeMapEntry(key, value, first);
													first = false;
												}}
											}}
										}}

							""");
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										bool hasOtherFields = this.{flat.Name} != null && !this.{flat.Name}.IsEmpty;
										if (hasOtherFields)
										{{
											for (let (key, value) in this.{flat.Name})
											{{
												if (Serialize.Util.Util.IsPrimitive(value.VariantType))
													serializer.SerializeMapEntry(key, value, false);
											}}
										}}

							""");
					}
				}
				else if (Util.IsPrimitive(flatValueType))
				{
					if (primitives.IsEmpty)
					{
						first = "!hasOtherFields";
						Compiler.EmitTypeBody(type,
							scope $"""
										bool hasOtherFields = this.{flat.Name} != null && !this.{flat.Name}.IsEmpty;
										if (hasOtherFields)
										{{
											bool first = true;
											for (let (key, value) in this.{flat.Name})
											{{
												serializer.SerializeMapEntry(key, value, first);
												first = false;
											}}
										}}

							""");
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										if (this.{flat.Name} != null)
											for (let (key, value) in this.{flat.Name})
												serializer.SerializeMapEntry(key, value, false);

							""");
					}
				}
			}

			for (let field in arrays)
				WriteSerializeForField(type, field, ref first);

			if (flatField != null)
			{
				let flat = flatField.Value;
				if (flatValueType == typeof(Variant))
				{
					if (primitives.IsEmpty && arrays.IsEmpty)
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										if (hasOtherFields)
										{{
											for (let (key, value) in this.{flat.Name})
											{{
												if (Serialize.Util.Util.IsList(value.VariantType))
												{{
													serializer.SerializeMapEntry(key, value, first);
													first = false;
												}}
											}}
										}}

							""");
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										if (hasOtherFields)
										{{
											for (let (key, value) in this.{flat.Name})
											{{
												if (Serialize.Util.Util.IsList(value.VariantType))
													serializer.SerializeMapEntry(key, value, false);
											}}
										}}

							""");
					}
				}
				else if (Util.IsList(flatValueType))
				{
					if (primitives.IsEmpty && arrays.IsEmpty)
					{
						first = "!hasOtherFields";
						Compiler.EmitTypeBody(type,
							scope $"""
										bool hasOtherFields = this.{flat.Name} != null && !this.{flat.Name}.IsEmpty;
										if (hasOtherFields)
										{{
											bool first = true;
											for (let (key, value) in this.{flat.Name})
											{{
												serializer.SerializeMapEntry(key, value, first);
												first = false;
											}}
										}}

							""");
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										if (this.{flat.Name} != null)
											for (let (key, value) in this.{flat.Name})
												serializer.SerializeMapEntry(key, value, false);			

							""");
					}
				}
			}

			for (let field in maps)
				WriteSerializeForField(type, field, ref first);

			if (flatField != null)
			{
				let flat = flatField.Value;
				if (flatValueType == typeof(Variant))
				{
					Compiler.EmitTypeBody(type,
						scope $"""

									if (this.{flat.Name} != null)
									{{
										for (let (key, value) in this.{flat.Name})
										{{
											if (Serialize.Util.Util.IsMap(value.VariantType))
												serializer.SerializeMapEntry(key, value, false);
										}}
									}}

						""");
				}
				else if (Util.IsMap(flatValueType))
				{
					if (primitives.IsEmpty && arrays.IsEmpty && maps.IsEmpty)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
										if (this.{flat.Name} != null)
										{{
											bool first = true;
											for (let (key, value) in this.{flat.Name})
											{{
												serializer.SerializeMapEntry(key, value, first);
												first = false;
											}}
										}}

							""");
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""

										if (this.{flat.Name} != null)
											for (let (key, value) in this.{flat.Name})
												serializer.SerializeMapEntry(key, value, false);

							""");
					}
				}
			}

			Compiler.EmitTypeBody(type,
				scope $"""
						}}
					}}

				""");
		}

		[Comptime]
		void WriteSerializeForEnum(Type type)
		{
			String tag = null;
			if (type.GetCustomAttribute<SerializableAttribute>() case .Ok(let attr))
				tag = attr.Tag;

			Compiler.EmitTypeBody(type,
				scope $"""
				public void Serialize<S>(S serializer)
					where S : Serialize.Implementation.ISerializer
				{{
					switch (this)
					{{

				""");

			for (let field in type.GetFields())
			{
				if (field.Name == "$payload" || field.Name == "$discriminator")
					continue;

				let fieldSerName = SerializedName(field);

				if (type.IsUnion)
				{
					if (field.FieldType.FieldCount == 1)
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								case .{field.Name}(let value):
									value.Serialize(serializer);

							""");
					}
					else
					{
						String tupleValues = scope .();
						bool firstTupleValue = true;
						for (let tupleField in field.FieldType.GetFields())
						{
							if (!firstTupleValue)
								tupleValues.Append(", ");
							tupleValues.AppendF("let _{}", tupleField.Name);
							firstTupleValue = false;
						}

						Compiler.EmitTypeBody(type,
							scope $"""
								case .{field.Name}({tupleValues}):
									serializer.SerializeMapStart({field.FieldType.FieldCount});

							""");

						String first = "true";
						if (tag != null)
						{
							Compiler.EmitTypeBody(type,
								scope $"""
										serializer.SerializeMapEntry("{tag}", "{fieldSerName}", true);

								""");

							first = "false";
						}

						for (let tupleField in field.FieldType.GetFields())
						{
							Compiler.EmitTypeBody(type,
								scope $"""
										serializer.SerializeMapEntry("{SerializedName(tupleField)}", _{tupleField.Name}, {first});

								""");
							first = "false";
						}

						Compiler.EmitTypeBody(type,
							scope $"""
									serializer.SerializeMapEnd();

							""");
					}
				}
				else
				{
					Compiler.EmitTypeBody(type,
						scope $"""
							case .{field.Name}:
								serializer.SerializeString("{fieldSerName}");

						""");
				}
			}

			Compiler.EmitTypeBody(type,
				scope $"""
					}}
				}}

				public static System.Result<Self> Deserialize<D>(D deserializer)
					where D : Serialize.Implementation.IDeserializer
				{{
				
				""");

			if (type.IsUnion)
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						let pos = deserializer.Reader.Position;
						System.Result<Self> result = default;


					""");



				for (let field in type.GetFields())
				{
					if (field.Name == "$payload" || field.Name == "$discriminator")
						continue;

					let fieldSerName = SerializedName(field);

					bool needsOk = false;
					for (let tupleField in field.FieldType.GetFields())
					{
						if (!tupleField.FieldType.IsValueType)
						{
							needsOk = true;
							break;
						}
					}

					Compiler.EmitTypeBody(type,
						scope $"""
							deserializer.Reader.Position = pos;
							deserializer.PushState();
							result = Deserialize{field.Name}();
							deserializer.PopState();
							if (result case .Ok(let val))
								return val;

							Result<Self> Deserialize{field.Name}()
							{{
						""");

					if (field.FieldType.FieldCount == 1)
					{
						for (let singleField in field.FieldType.GetFields())
						{
							Compiler.EmitTypeBody(type,
								scope $"""

										let value = Try!({singleField.FieldType}.Deserialize(deserializer));
										return .Ok(.{field.Name}((.)value));

								""");
						}
					}
					else
					{
						Compiler.EmitTypeBody(type,
							scope $"""
								{(needsOk ? "\n\t\tbool ok = false;" : "")}
									Try!(deserializer.DeserializeStructStart({field.FieldType.FieldCount}));
	
	
							""");
	
						String tupleValueList = scope .();
						String tupleFieldList = scope .();
						bool firstTupleField = true;
						for (let tupleField in field.FieldType.GetFields())
						{
							if (!firstTupleField)
							{
								tupleValueList.Append(", ");
								tupleFieldList.Append(", ");
							}
							tupleValueList.AppendF("_{}", tupleField.Name);
							tupleFieldList.AppendF("\"{}\"", SerializedName(tupleField));
	
							Compiler.EmitTypeBody(type,
								scope $"""
										{tupleField.FieldType} _{tupleField.Name} = default;
										{(tupleField.FieldType.IsValueType ? "" : scope $"defer {{ if (!ok) delete _{tupleField.Name}; }}\n")}
								
								""");
	
							firstTupleField = false;
						}
	
						if (tag != null)
						{
							if (!firstTupleField)
								tupleFieldList.Append(", ");
							tupleFieldList.AppendF("\"{}\"", tag);
						}
	
						Compiler.EmitTypeBody(type,
							scope $"""
									System.Collections.List<System.StringView> fieldsLeft = scope .(){{ {tupleFieldList} }};
									delegate System.Result<void, Serialize.FieldDeserializeError>(System.StringView) mapField = scope [&] (field) => {{
										switch (field)
										{{
	
							""");
	
						if (tag != null)
						{
							Compiler.EmitTypeBody(type,
								scope $"""
											case "{tag}":
												let tag = deserializer.DeserializeString();
												if (tag case .Err)
													return .Err(.DeserializationError);
												defer delete tag.Value;
												if (tag != "{fieldSerName}")
													return .Err(.DeserializationError);
												fieldsLeft.Remove("{tag}");
												return .Ok;
	
								""");
						}
	
						for (let tupleField in field.FieldType.GetFields())
						{
							Compiler.EmitTypeBody(type,
								scope $"""
											case "{SerializedName(tupleField)}":
												let result = {tupleField.FieldType}.Deserialize(deserializer);
												if (result case .Err)
													return .Err(.DeserializationError);
												_{tupleField.Name} = (.)result.Get();
												fieldsLeft.Remove("{SerializedName(tupleField)}");
												return .Ok;
	
								""");
						}
	
						Compiler.EmitTypeBody(type,
							scope $"""
										}}
	
										return .Err(.UnknownField);
									}};
	
									bool first = true;
									for (let i < {field.FieldType.FieldCount + (tag != null ? 1 : 0)})
									{{
										Try!(deserializer.DeserializeStructField(mapField, fieldsLeft, first));
										first = false;
									}}
	
									Try!(deserializer.DeserializeStructEnd());
									{(needsOk ? "\n\t\tok = true;" : "")}
									return .Ok(.{field.Name}({tupleValueList}));
							""");
						}

						Compiler.EmitTypeBody(type,
							scope $"""
							}}


						""");
				}

				Compiler.EmitTypeBody(type,
					scope $"""
						DeserializeError error = new .(new $"Struct doesn't match any enum fields", deserializer, 1, pos);
						deserializer.SetError(error);
						return .Err;

					""");
			}
			else
			{
				Compiler.EmitTypeBody(type,
					scope $"""
						let start = deserializer.Reader.Position + 1;
						let str = Try!(deserializer.DeserializeString());
						defer delete str;
						switch (str)
						{{

					""");

				for (let field in type.GetFields())
				{
					Compiler.EmitTypeBody(type,
						scope $"""
							case "{SerializedName(field)}": return .{field.Name};

						""");
				}

				Compiler.EmitTypeBody(type,
					scope $"""
						}}
	
						let end = deserializer.Reader.Position - 1;
						DeserializeError error = new .(new $"Unknown enum value '{{str}}'", deserializer, end - start, start);
						deserializer.SetError(error);
						return .Err;

					""");
			}

			Compiler.EmitTypeBody(type,
				scope $"""
				}}
				""");
		}

		[Comptime]
		void WriteSerializeInnerTypeEnum(Type type)
		{
			Compiler.EmitTypeBody(type,
				"""
				[NoShow]
				public Type __SerializeActualType
				{
					get
					{
						switch (this)
						{

				""");

			for (let field in type.GetFields())
			{
				if (field.Name == "$payload" || field.Name == "$discriminator")
					continue;

				String fieldType = field.FieldType.ToString(.. scope .());
				if (!fieldType.Contains(','))
				{
					fieldType.Remove(0, 1);
					fieldType.RemoveFromEnd(1);
				}	
				Compiler.EmitTypeBody(type,
					scope $"""
							case .{field.Name}: return typeof({fieldType});

					""");
			}

			Compiler.EmitTypeBody(type,
				"""
						}
					}
				}


				""");
		}

		StringView SerializedName(FieldInfo field)
		{
			if (field.GetCustomAttribute<SerializeAttribute>() case .Ok(let attr))
			{
				if (attr.Rename != null)
					return attr.Rename;
			}

			return field.Name;
		}
	}
}